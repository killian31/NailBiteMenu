import AppKit
import SwiftUI
import Combine
import QuartzCore

// The alert, in two levels.
//   1. Edge glow: vermilion light hits every screen edge within 90 ms, swells inward, holds, and draws back. 1.9 s.
//   2. Reset: the glow stays, the screen dims, and a card offers 30 seconds of hands-down breathing.
//      The glow breathes with you and drains away as the timer runs out.
// Glow panels never take focus, ignore the mouse and join every Space, full-screen apps included.

// MARK: - Timeline

/// The level-1 glow as a pure function of time, so the live animation and the screenshots
/// come from the same numbers.
enum GlowTimeline {
    /// The edges are unmistakable within this, so the alert keeps up with detection.
    static let attack: Double = 0.09
    /// The slower part: deep light keeps swelling inward after the edges are lit.
    static let swell: Double = 0.5
    static let release: Double = 1.1 // start drawing back
    static let duration: Double = 1.9

    /// Glow level 0…1 at `t` seconds after the start.
    static func level(at t: Double, reduceMotion: Bool) -> Double {
        let attack = reduceMotion ? 0.16 : Self.attack
        switch t {
        case ..<0: return 0
        case ..<attack: return easeOutCubic(t / attack)
        case ..<release: return 1 - 0.12 * easeInOut((t - attack) / (release - attack)) // settles a touch
        case ..<duration: return 0.88 * (1 - easeInOut((t - release) / (duration - release)))
        default: return 0
        }
    }

    /// How far the deep light reaches, 0…1: it swells after the attack, then retreats with the level.
    static func reach(at t: Double, reduceMotion: Bool) -> Double {
        if reduceMotion { return 1 }
        return t < release ? easeOutCubic(min(1, max(0, t) / swell)) : level(at: t, reduceMotion: false) / 0.88
    }

    private static func easeOutCubic(_ x: Double) -> Double { 1 - pow(1 - x, 3) }
    private static func easeInOut(_ x: Double) -> Double { x < 0.5 ? 4 * x * x * x : 1 - pow(-2 * x + 2, 3) / 2 }
}

// MARK: - Glow view

/// Layers per screen, all animated by opacity only (cheap on the GPU, identical in screenshots):
///   scrim  black, only for the reset
///   tint   a faint vermilion wash over everything
///   far    light reaching deep into the screen
///   near   the body of the glow, close to the edges
///   rim    the bright edge itself
/// `far` lags `near`, so the light visibly travels inward as it comes on and back out as it goes.
final class EdgeGlowView: NSView {
    private let scrim = CALayer()
    private let tint = CALayer()
    private let far = CALayer()
    private let near = CALayer()
    private let rim = CALayer()
    private let caption = CALayer()

    init(frame: NSRect, cornerRadius: CGFloat = 10) {
        super.init(frame: frame)
        wantsLayer = true
        layer = CALayer()
        layer?.masksToBounds = true

        let bounds = CGRect(origin: .zero, size: frame.size)
        let short = min(bounds.width, bounds.height)
        scrim.backgroundColor = NSColor.black.cgColor
        tint.backgroundColor = NSColor.signalGlow.cgColor
        rim.contents = Self.glowImage(size: bounds.size, cornerRadius: cornerRadius, falloff: short * 0.01)
        near.contents = Self.glowImage(size: bounds.size, cornerRadius: cornerRadius, falloff: short * 0.04)
        far.contents = Self.glowImage(size: bounds.size, cornerRadius: cornerRadius, falloff: short * 0.15)
        caption.contentsGravity = .center
        for l in [scrim, tint, far, near, rim, caption] {
            l.frame = bounds
            l.opacity = 0
            layer?.addSublayer(l)
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    /// Light falling off exponentially from the screen edge, following the display's rounded corners.
    /// Drawn at a quarter of the point size: it is all soft gradient, so upscaling costs nothing visible.
    private static func glowImage(size: CGSize, cornerRadius: CGFloat, falloff: CGFloat) -> CGImage? {
        let k: CGFloat = 0.25
        let w = max(2, Int(size.width * k)), h = max(2, Int(size.height * k))
        let half = CGSize(width: CGFloat(w) / 2, height: CGFloat(h) / 2)
        let r = cornerRadius * k, f = falloff * k
        var pixels = [UInt8](repeating: 0, count: w * h * 4)
        let c = NSColor.signalGlow.usingColorSpace(.displayP3)!
        let rgb = [c.redComponent, c.greenComponent, c.blueComponent]
        for y in 0..<h {
            for x in 0..<w {
                // Distance inside a rounded rectangle (rounded-box SDF, negated).
                let px = abs(CGFloat(x) + 0.5 - half.width) - (half.width - r)
                let py = abs(CGFloat(y) + 0.5 - half.height) - (half.height - r)
                let outside = hypot(max(px, 0), max(py, 0)) + min(max(px, py), 0) - r
                let d = max(0, -outside)
                let alpha = exp(-d / f)
                let i = (y * w + x) * 4
                for ch in 0..<3 { pixels[i + ch] = UInt8(rgb[ch] * alpha * 255) } // premultiplied
                pixels[i + 3] = UInt8(alpha * 255)
            }
        }
        guard let provider = CGDataProvider(data: Data(pixels) as CFData) else { return nil }
        return CGImage(width: w, height: h, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: w * 4,
                       space: CGColorSpace(name: CGColorSpace.displayP3)!,
                       bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                       provider: provider, decode: nil, shouldInterpolate: true, intent: .defaultIntent)
    }

    // MARK: Appearance at a given level

    private struct Values { var rim, near, far, tint: Float }

    /// `reach` defaults to the level itself, so deep light trails the edges (v²) when nothing else drives it.
    /// Reduce Motion keeps one shape and only fades it.
    private func values(_ level: Double, reach: Double? = nil, reduceMotion: Bool) -> Values {
        let v = Float(max(0, min(1, level)))
        let r = reduceMotion ? 1 : Float(max(0, min(1, reach ?? level)))
        return Values(rim: 0.7 * v, near: 0.5 * v, far: 0.42 * v * r, tint: 0.05 * v)
    }

    private var glowLayers: [CALayer] { [rim, near, far, tint] }

    private func set(_ v: Values) {
        rim.opacity = v.rim; near.opacity = v.near; far.opacity = v.far; tint.opacity = v.tint
    }

    /// Sets a still frame (used by screenshots and to rest at zero).
    func apply(level: Double, reach: Double? = nil, scrim scrimLevel: Double = 0, reduceMotion: Bool = false) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        for l in [scrim, tint, far, near, rim, caption] { l.removeAllAnimations() }
        set(values(level, reach: reach, reduceMotion: reduceMotion))
        scrim.opacity = Float(scrimLevel)
        caption.opacity = Float(min(1, level * 1.4))
        CATransaction.commit()
    }

    /// Level 1: the whole 1.9 s glow, starting exactly at `start` (Core Animation time).
    func play(at start: CFTimeInterval, caption image: NSImage?, edges: Bool, reduceMotion: Bool) {
        setCaption(image)
        apply(level: 0, reduceMotion: reduceMotion)
        let fps = 60.0
        let n = Int(GlowTimeline.duration * fps) + 1
        let times = (0..<n).map { Double($0) / fps }
        let levels = times.map { GlowTimeline.level(at: $0, reduceMotion: reduceMotion) }
        let vals = times.indices.map {
            values(levels[$0], reach: GlowTimeline.reach(at: times[$0], reduceMotion: reduceMotion), reduceMotion: reduceMotion)
        }
        let begin = layer!.convertTime(start, from: nil)

        func keyframes(_ path: String, _ values: [Any], on target: CALayer) {
            let a = CAKeyframeAnimation(keyPath: path)
            a.values = values
            a.calculationMode = .linear
            a.duration = GlowTimeline.duration
            a.beginTime = begin
            a.fillMode = .both
            a.isRemovedOnCompletion = false
            target.add(a, forKey: path)
        }
        if edges {
            keyframes("opacity", vals.map(\.rim), on: rim)
            keyframes("opacity", vals.map(\.near), on: near)
            keyframes("opacity", vals.map(\.far), on: far)
            keyframes("opacity", vals.map(\.tint), on: tint)
        }
        keyframes("opacity", levels.map { Float(min(1, $0 * 1.4)) }, on: caption)
        if !reduceMotion {
            // The caption drops 8 pt into place with the sweep.
            keyframes("transform.translation.y", levels.map { 8 * (1 - min(1, $0 * 1.2)) }, on: caption)
        }
    }

    /// Level 2: move to a steady or breathing level from wherever the glow is now.
    func transition(to level: Double, scrim scrimLevel: Double, duration: Double, start: CFTimeInterval? = nil,
                    timing: CAMediaTimingFunctionName = .easeInEaseOut, reduceMotion: Bool) {
        let v = values(level, reduceMotion: reduceMotion)
        let begin = start.map { layer!.convertTime($0, from: nil) }
        func animate(_ to: Float, on target: CALayer) {
            let from = target.presentation()?.opacity ?? target.opacity
            target.removeAnimation(forKey: "opacity")
            target.opacity = to
            let a = CABasicAnimation(keyPath: "opacity")
            a.fromValue = from
            a.toValue = to
            a.duration = duration
            a.timingFunction = CAMediaTimingFunction(name: timing)
            if let begin { a.beginTime = begin; a.fillMode = .backwards }
            target.add(a, forKey: "opacity")
        }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        caption.removeAllAnimations(); caption.opacity = 0
        animate(v.rim, on: rim)
        animate(v.near, on: near)
        animate(v.far, on: far)
        animate(v.tint, on: tint)
        animate(Float(scrimLevel), on: scrim)
        CATransaction.commit()
    }

    func setCaption(_ image: NSImage?) {
        caption.contents = image
        guard let image, let screen = window?.screen ?? NSScreen.main else { return }
        caption.contentsScale = screen.backingScaleFactor
        // Centered, just under the menu bar.
        let top = bounds.height - (screen.frame.maxY - screen.visibleFrame.maxY) - 14
        caption.frame = CGRect(x: bounds.midX - image.size.width / 2, y: top - image.size.height,
                               width: image.size.width, height: image.size.height)
    }

    /// "Hands down · Safari" on a vermilion tag. Drawn once per alert from SwiftUI.
    static func captionImage(app: String?) -> NSImage? {
        let view = NSHostingView(rootView: GlowCaption(app: app))
        view.frame.size = view.fittingSize
        guard let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return nil }
        view.cacheDisplay(in: view.bounds, to: rep)
        let image = NSImage(size: view.bounds.size)
        image.addRepresentation(rep)
        return image
    }
}

private struct GlowCaption: View {
    let app: String?

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "hand.raised.fill")
                .font(.system(size: 13, weight: .semibold))
            Text("Hands down")
                .font(.system(size: 14, weight: .semibold))
            if let app {
                Text(app)
                    .font(.system(size: 14))
                    .opacity(0.8)
            }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 14)
        .frame(height: 32)
        .background(Color(nsColor: NSColor(hex: 0xC8341C)), in: .capsule)
        .environment(\.colorScheme, .dark)
    }
}

// MARK: - Panels

private final class GlowPanel: NSPanel {
    let glow: EdgeGlowView
    let screenFrame: NSRect

    init(screen: NSScreen) {
        screenFrame = screen.frame
        glow = EdgeGlowView(frame: NSRect(origin: .zero, size: screen.frame.size))
        super.init(contentRect: screen.frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        AlertPresenter.configure(self, level: .screenSaver)
        ignoresMouseEvents = true
        contentView = glow
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

/// The reset card. It can be clicked (and then answers Return and Esc), but it is never made key on its own.
private final class CardPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

@MainActor
enum AlertPresenter {
    private static var panels: [GlowPanel] = []
    private static var hideWork: DispatchWorkItem?
    private static var card: CardPanel?
    /// The app that was in front when the reset card appeared, to hand focus back if the card took it.
    private static var previousApp: NSRunningApplication?
    private static var screenObserver: NSObjectProtocol?

    static var reduceMotion: Bool { NSWorkspace.shared.accessibilityDisplayShouldReduceMotion }

    /// People who drive the Mac from the keyboard or with VoiceOver need the reset card focused to use it.
    static var needsKeyboardFocus: Bool {
        NSWorkspace.shared.isVoiceOverEnabled || NSApp.isFullKeyboardAccessEnabled
    }

    /// Builds the panels ahead of the first alert so it starts on time, and again whenever displays change.
    static func prepare() {
        _ = glowPanels()
        screenObserver = screenObserver ?? NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main
        ) { _ in MainActor.assumeIsolated { _ = glowPanels() } }
    }

    private static func glowPanels() -> [GlowPanel] {
        let screens = NSScreen.screens
        if panels.map(\.screenFrame) != screens.map(\.frame) {
            panels.forEach { $0.orderOut(nil) }
            panels = screens.map(GlowPanel.init)
        }
        return panels
    }

    /// The screen the pointer is on: where the person is most likely looking.
    private static var focusScreen: NSScreen? {
        NSScreen.screens.first { NSMouseInRect(NSEvent.mouseLocation, $0.frame, false) } ?? NSScreen.main
    }

    // MARK: Level 1

    /// Everything slow (panels, caption) is built first; only then does `schedule` fix the shared start time
    /// for the sound and the glow, so the attack is never cut short.
    static func showGlow(app: String?, edges: Bool, label: Bool, schedule: () -> CFTimeInterval) {
        guard card == nil else { return }
        if let pending = hideWork, !pending.isCancelled { return } // a glow is already on screen for this episode
        let focus = focusScreen?.frame
        let caption = label ? EdgeGlowView.captionImage(app: app) : nil
        let targets = glowPanels()
        let start = schedule()
        for panel in targets {
            panel.orderFrontRegardless()
            panel.glow.play(at: start, caption: panel.screenFrame == focus ? caption : nil, edges: edges, reduceMotion: reduceMotion)
        }
        announce(app.map { "Hands down. Nail-biting detected in \($0)." } ?? "Hands down. Nail-biting detected.")
        hideAll(after: start - CACurrentMediaTime() + GlowTimeline.duration + 0.05)
    }

    private static func hideAll(after delay: TimeInterval) {
        hideWork?.cancel()
        let work = DispatchWorkItem {
            panels.forEach { $0.glow.apply(level: 0); $0.orderOut(nil) }
            hideWork = nil
        }
        hideWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + max(0, delay), execute: work)
    }

    // MARK: Level 2

    private static let cardSize = CGSize(width: 580, height: 560)
    private static var edgesOn = true

    static func showInterrupt(edges: Bool, schedule: () -> CFTimeInterval) {
        guard card == nil, let screen = focusScreen else { return }
        hideWork?.cancel()
        hideWork = nil
        edgesOn = edges
        previousApp = NSWorkspace.shared.frontmostApplication

        // A fixed, transparent frame with the card centered inside, so phases of different heights stay centered.
        // Clicks on the transparent margin fall through to the app underneath.
        let host = NSHostingView(rootView: InterruptView(onClose: { dismissInterrupt() }, onGlow: setGlow))
        host.sizingOptions = []
        let frame = NSRect(x: screen.frame.midX - cardSize.width / 2, y: screen.frame.midY - cardSize.height / 2,
                           width: cardSize.width, height: cardSize.height)
        let panel = CardPanel(contentRect: frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        configure(panel, level: NSWindow.Level(rawValue: NSWindow.Level.screenSaver.rawValue + 1))
        panel.contentView = host
        panel.alphaValue = 0
        let targets = glowPanels()

        let start = schedule()
        for glow in targets {
            glow.orderFrontRegardless()
            glow.glow.transition(to: edges ? 0.8 : 0, scrim: 0.42, duration: reduceMotion ? 0.16 : 0.12, start: start,
                                 timing: .easeOut, reduceMotion: reduceMotion)
        }
        panel.orderFrontRegardless()
        if needsKeyboardFocus { panel.makeKey() } // still never activates the app
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.22
            ctx.timingFunction = CAMediaTimingFunction(controlPoints: 0.23, 1, 0.32, 1)
            panel.animator().alphaValue = 1
        }
        card = panel
        announce("Still biting. A 30-second hands-down reset is on screen.")
    }

    /// Called by the reset card: the glow breathes and drains with the timer.
    private static func setGlow(_ level: Double, _ duration: Double) {
        for panel in panels {
            panel.glow.transition(to: edgesOn ? level : 0, scrim: level > 0 ? 0.42 : 0, duration: duration,
                                  timing: reduceMotion ? .linear : .easeInEaseOut, reduceMotion: reduceMotion)
        }
    }

    static func dismissInterrupt() {
        guard let panel = card else { return }
        card = nil
        if panel.isKeyWindow { previousApp?.activate() } // hand the keyboard back to whatever had it
        previousApp = nil
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.18
            panel.animator().alphaValue = 0
        }, completionHandler: { panel.orderOut(nil) })
        for p in panels {
            p.glow.transition(to: 0, scrim: 0, duration: 0.5, timing: .easeOut, reduceMotion: reduceMotion)
        }
        hideAll(after: 0.55)
    }

    // MARK: Helpers

    fileprivate static func configure(_ panel: NSPanel, level: NSWindow.Level) {
        panel.level = level
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false
        panel.animationBehavior = .none
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
    }

    private static func announce(_ text: String) {
        NSAccessibility.post(element: NSApp as Any, notification: .announcementRequested,
                             userInfo: [.announcement: text, .priority: NSAccessibilityPriorityLevel.high.rawValue])
    }
}

// MARK: - Reset card

struct InterruptView: View {
    let onClose: () -> Void
    /// (glow level 0…1, seconds to get there)
    let onGlow: (Double, Double) -> Void

    enum Phase { case prompt, reset, done }
    static let resetLength = 30
    private static let breath = 4 // seconds in, seconds out

    @State private var phase = Phase.prompt
    @State private var remaining = resetLength
    @State private var idleSeconds = 0
    @State private var appeared = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let tick = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    init(onClose: @escaping () -> Void, onGlow: @escaping (Double, Double) -> Void,
         phase: Phase = .prompt, remaining: Int = resetLength) {
        self.onClose = onClose
        self.onGlow = onGlow
        _phase = State(initialValue: phase)
        _remaining = State(initialValue: remaining)
    }

    private var phaseTransition: AnyTransition {
        reduceMotion ? .opacity : .opacity.combined(with: .offset(y: 4))
    }
    private func go(_ next: Phase) {
        withAnimation(reduceMotion ? .easeOut(duration: 0.2) : .timingCurve(0.23, 1, 0.32, 1, duration: 0.22)) { phase = next }
    }
    /// Someone using VoiceOver or the keyboard needs longer to reach the buttons.
    private var promptTimeout: Int { AlertPresenter.needsKeyboardFocus ? 60 : 20 }

    private var elapsed: Int { Self.resetLength - remaining }
    private var breathingIn: Bool { (elapsed / Self.breath) % 2 == 0 }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Space.xl) {
            switch phase {
            case .prompt: prompt.transition(phaseTransition)
            case .reset: reset.transition(phaseTransition)
            case .done: done.transition(phaseTransition)
            }
        }
        .foregroundStyle(Color.dsText)
        .frame(width: 400, alignment: .leading)
        .padding(DS.Space.xxl)
        .card(cornerRadius: DS.Radius.sheet)
        .signalEdge(phase != .done, inset: DS.Space.xxl)
        .shadow(color: .black.opacity(0.28), radius: 40, y: 18)
        .scaleEffect(appeared || reduceMotion ? 1 : 0.97)
        .frame(maxWidth: .infinity, maxHeight: .infinity) // centered in the panel's fixed frame
        .onAppear { withAnimation(.smooth(duration: 0.3)) { appeared = true } }
        .onReceive(tick) { _ in advance() }
    }

    private var prompt: some View {
        Group {
            VStack(alignment: .leading, spacing: DS.Space.s) {
                Text("Still biting")
                    .font(.dsFigure(64))
                Text(reduceMotion ? "Give your hands 30 seconds somewhere else. Lay them flat on the desk and breathe slowly."
                                  : "Give your hands 30 seconds somewhere else. Lay them flat on the desk and breathe with the edges of the screen.")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.dsTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            HStack(spacing: DS.Space.s) {
                Spacer()
                Button("Not Now", action: onClose)
                    .keyboardShortcut(.cancelAction)
                    .buttonStyle(QuietButtonStyle(large: true))
                Button("Start Reset", action: startReset)
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(InkButtonStyle(large: true))
            }
        }
    }

    /// Big countdown, the breath cue, and a bar. The glow around the screen does the pacing.
    private var reset: some View {
        Group {
            HStack(alignment: .lastTextBaseline, spacing: DS.Space.l) {
                Text("\(remaining)")
                    .font(.dsFigure(120))
                    .contentTransition(.numericText(countsDown: true))
                    .animation(DS.Motion.counter, value: remaining)
                    .frame(width: 120, alignment: .leading)
                VStack(alignment: .leading, spacing: 2) {
                    Text(breathingIn ? "Breathe in" : "Breathe out")
                        .font(.system(size: 22, weight: .semibold))
                        .contentTransition(.opacity)
                        .animation(.easeInOut(duration: 0.4), value: breathingIn)
                    Text("Hands flat, away from your face")
                        .font(.dsBody)
                        .foregroundStyle(Color.dsTextSecondary)
                }
            }
            .accessibilityElement(children: .combine)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.dsSurfaceRaised)
                    Capsule().fill(Color.dsText)
                        .frame(width: geo.size.width * CGFloat(elapsed) / CGFloat(Self.resetLength))
                        .animation(.linear(duration: 1), value: remaining)
                }
            }
            .frame(height: 4)
            HStack {
                Text(reduceMotion ? "Breathe slowly until the timer ends" : "The red fades as you go")
                    .font(.dsCaption)
                    .foregroundStyle(Color.dsTextTertiary)
                Spacer()
                Button("End Early", action: onClose)
                    .keyboardShortcut(.cancelAction)
                    .buttonStyle(QuietButtonStyle())
            }
        }
    }

    private var done: some View {
        VStack(alignment: .leading, spacing: DS.Space.s) {
            Text("Done")
                .font(.dsFigure(64))
            Text("Back to it.")
                .font(.system(size: 14))
                .foregroundStyle(Color.dsTextSecondary)
        }
    }

    private func startReset() {
        idleSeconds = 0
        go(.reset)
        breathe()
    }

    /// Glow level for the breath that starts now: brighter on the in-breath, and lower overall as time runs out.
    private func breathe() {
        if reduceMotion {
            onGlow(0.6 * Double(remaining - 1) / Double(Self.resetLength), 1)
        } else if elapsed % Self.breath == 0 {
            let left = Double(max(0, remaining - Self.breath)) / Double(Self.resetLength)
            onGlow(left * (breathingIn ? 0.95 : 0.4), Double(Self.breath))
        }
    }

    private func advance() {
        switch phase {
        case .prompt:
            // Don't trap someone who walked away: close an unanswered prompt after 20 s.
            idleSeconds += 1
            if idleSeconds >= promptTimeout { onClose() }
        case .reset:
            remaining -= 1
            if remaining <= 0 {
                go(.done)
                onGlow(0, 0.8)
            } else {
                breathe()
            }
        case .done:
            idleSeconds += 1
            if idleSeconds >= 2 { onClose() } // linger 2 s on "Done"
        }
    }
}
