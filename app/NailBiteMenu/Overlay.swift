import AppKit
import SwiftUI
import Combine

/// Shows the two alert levels. Neither one activates the app, so the user's current app keeps focus
/// and no Space switch happens.
@MainActor
enum AlertPresenter {
    private static var banner: NSPanel?
    private static var bannerDismiss: DispatchWorkItem?
    private static var interrupt: NSPanel?

    // MARK: Level 1 – banner under the menu bar

    static func showBanner(app: String?) {
        guard interrupt == nil, let screen = NSScreen.main else { return }
        dismissBanner(animated: false)

        let host = NSHostingView(rootView: BannerView(app: app, onTap: { dismissBanner() }))
        let size = host.fittingSize
        let visible = screen.visibleFrame
        let origin = NSPoint(x: visible.midX - size.width / 2, y: visible.maxY - size.height - 10)

        let panel = makePanel(frame: NSRect(origin: origin, size: size), level: .statusBar)
        panel.contentView = host
        panel.alphaValue = 0
        panel.setFrameOrigin(NSPoint(x: origin.x, y: origin.y + 12))
        panel.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.28
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().alphaValue = 1
            panel.animator().setFrameOrigin(origin)
        }
        banner = panel

        let work = DispatchWorkItem { dismissBanner() }
        bannerDismiss = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 4, execute: work)
    }

    static func dismissBanner(animated: Bool = true) {
        bannerDismiss?.cancel()
        bannerDismiss = nil
        guard let panel = banner else { return }
        banner = nil
        guard animated else { panel.orderOut(nil); return }
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.2
            panel.animator().alphaValue = 0
        }, completionHandler: { panel.orderOut(nil) })
    }

    // MARK: Level 2 – full-screen interrupt with the hands-down reset

    static func showInterrupt() {
        guard interrupt == nil, let screen = NSScreen.main else { return }
        dismissBanner(animated: false)

        let panel = KeyPanel(contentRect: screen.frame,
                             styleMask: [.borderless, .nonactivatingPanel],
                             backing: .buffered, defer: false)
        configure(panel, level: .screenSaver)
        panel.contentView = NSHostingView(rootView: InterruptView(onClose: { dismissInterrupt() }))
        panel.alphaValue = 0
        panel.orderFrontRegardless()
        panel.makeKey()
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.25
            panel.animator().alphaValue = 1
        }
        interrupt = panel
    }

    static func dismissInterrupt() {
        guard let panel = interrupt else { return }
        interrupt = nil
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.2
            panel.animator().alphaValue = 0
        }, completionHandler: { panel.orderOut(nil) })
    }

    // MARK: Helpers

    private static func makePanel(frame: NSRect, level: NSWindow.Level) -> NSPanel {
        let panel = NSPanel(contentRect: frame, styleMask: [.borderless, .nonactivatingPanel],
                            backing: .buffered, defer: false)
        configure(panel, level: level)
        return panel
    }

    private static func configure(_ panel: NSPanel, level: NSWindow.Level) {
        panel.level = level
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
    }
}

/// Borderless panels refuse key status by default; the interrupt needs it for Return / Esc.
private final class KeyPanel: NSPanel {
    override var canBecomeKey: Bool { true }
}

// MARK: - Views

private struct BannerView: View {
    let app: String?
    let onTap: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: DS.Space.m) {
                BiteBadge(size: 34)
                    .symbolEffect(.bounce, options: .nonRepeating, isActive: !reduceMotion)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Hands down")
                        .font(.dsHeadline)
                        .foregroundStyle(Color.dsText)
                    Text(app.map { "Nail-biting detected in \($0)" } ?? "Nail-biting detected")
                        .font(.subheadline)
                        .foregroundStyle(Color.dsTextSecondary)
                }
            }
            .padding(.leading, DS.Space.m)
            .padding(.trailing, DS.Space.xl)
            .padding(.vertical, DS.Space.s + 2)
            .contentShape(.capsule)
            .floatingSurface(Capsule())
        }
        .buttonStyle(.plain)
        .padding(DS.Space.l) // room for the shadow
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isStaticText)
    }
}

private struct InterruptView: View {
    let onClose: () -> Void

    private enum Phase { case prompt, reset, done }
    private static let resetLength = 30
    private static let breath = 4 // seconds in, seconds out

    @State private var phase = Phase.prompt
    @State private var remaining = resetLength
    @State private var idleSeconds = 0
    @State private var appeared = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let tick = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var breathingIn: Bool { ((Self.resetLength - remaining) / Self.breath) % 2 == 0 }

    var body: some View {
        ZStack {
            Color(light: 0x32292F, dark: 0x120E10).opacity(0.55)
                .ignoresSafeArea()
                .onTapGesture { if phase == .prompt { onClose() } }

            VStack(spacing: DS.Space.xl - 4) {
                switch phase {
                case .prompt: prompt
                case .reset: reset
                case .done: done
                }
            }
            .foregroundStyle(Color.dsText)
            .frame(width: 400)
            .padding(DS.Space.xxl)
            .card(cornerRadius: DS.Radius.sheet)
            .shadow(color: .black.opacity(0.25), radius: 30, y: 14)
            .scaleEffect(appeared || reduceMotion ? 1 : 0.94)
            .opacity(appeared ? 1 : 0)
            .animation(DS.Motion.snappy, value: phase)
        }
        .onAppear { withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { appeared = true } }
        .onReceive(tick) { _ in advance() }
    }

    private var prompt: some View {
        Group {
            BiteBadge(size: 64)
            VStack(spacing: DS.Space.s) {
                Text("You’re still biting")
                    .font(.title.weight(.bold))
                Text("Rest your hands for 30 seconds. Make a loose fist or lay them flat on the desk. Doing something else with your hands breaks the loop.")
                    .font(.dsBody)
                    .foregroundStyle(Color.dsTextSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            HStack(spacing: DS.Space.m) {
                Button("Not Now", action: onClose)
                    .keyboardShortcut(.cancelAction)
                    .glassButton()
                Button("Start 30-Second Reset") { idleSeconds = 0; phase = .reset }
                    .keyboardShortcut(.defaultAction)
                    .glassButton(prominent: true)
            }
            .controlSize(.large)
        }
    }

    /// Countdown ring that also paces breathing: it swells for 4 s, settles for 4 s.
    private var reset: some View {
        Group {
            ZStack {
                Circle()
                    .fill(Color.dsBiteTint)
                    .scaleEffect(reduceMotion ? 0.9 : (breathingIn ? 1.0 : 0.72))
                    .animation(.easeInOut(duration: Double(Self.breath)), value: breathingIn)
                Circle()
                    .stroke(Color.dsSurfaceMuted, lineWidth: 10)
                Circle()
                    .trim(from: 0, to: CGFloat(remaining) / CGFloat(Self.resetLength))
                    .stroke(Color.dsBite, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 1), value: remaining)
                Text("\(remaining)")
                    .font(.dsNumber(48, weight: .bold))
                    .contentTransition(.numericText(countsDown: true))
                    .animation(DS.Motion.counter, value: remaining)
            }
            .frame(width: 150, height: 150)
            VStack(spacing: 6) {
                Text(breathingIn ? "Breathe in" : "Breathe out")
                    .font(.dsTitle)
                    .contentTransition(.opacity)
                    .animation(DS.Motion.smooth, value: breathingIn)
                Text("Hands down, away from your face, until the timer ends.")
                    .foregroundStyle(Color.dsTextSecondary)
                    .multilineTextAlignment(.center)
            }
            Button("End Early", action: onClose)
                .keyboardShortcut(.cancelAction)
                .glassButton()
        }
    }

    private var done: some View {
        Group {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 56))
                .foregroundStyle(Color.dsWin)
                .symbolEffect(.bounce, options: .nonRepeating, isActive: !reduceMotion)
            Text("Nice work")
                .font(.title.weight(.bold))
            Text("Back to it.")
                .foregroundStyle(Color.dsTextSecondary)
        }
    }

    private func advance() {
        switch phase {
        case .prompt:
            // Don't trap someone who walked away: close an unanswered prompt after 20 s.
            idleSeconds += 1
            if idleSeconds >= 20 { onClose() }
        case .reset:
            remaining -= 1
            if remaining <= 0 { phase = .done }
        case .done:
            idleSeconds += 1
            if idleSeconds >= 2 { onClose() } // linger 2 s on "Nice work"
        }
    }
}
