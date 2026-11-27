#if DEBUG
import SwiftUI
import AppKit

/// Debug-only: renders every surface with mock data into the container's tmp folder, then quits.
/// Run the Debug build with: -NBDesignShots YES -preferences.startMonitoringOnLaunch NO
/// Nothing here touches the real history: the tracker is in-memory and AppStorage goes to its own suite.
@MainActor
enum DesignShots {
    static func runIfRequested() {
        guard UserDefaults.standard.bool(forKey: "NBDesignShots") else { return }
        Task { await run() ; NSApp.terminate(nil) }
    }

    private static let out = FileManager.default.temporaryDirectory.appendingPathComponent("design-shots", isDirectory: true)
    private static let store = UserDefaults(suiteName: "design-shots")!

    private static func run() async {
        try? FileManager.default.removeItem(at: out)
        try? FileManager.default.createDirectory(at: out.appendingPathComponent("frames"), withIntermediateDirectories: true)
        print("DesignShots →", out.path)

        let prefs = AppPreferences()
        let tracker = mockTracker()
        let monitor = MonitorViewModel(preferences: prefs, tracker: tracker)
        monitor.screenshotMode = true
        monitor.isRunning = true
        monitor.live.confidence = 0.34

        var todayWindow: [Bool: NSImage] = [:]
        for dark in [false, true] {
            let mode = dark ? "dark" : "light"
            for range in ["Today", "Week"] {
                store.set(range, forKey: "menuRange")
                let popover = await snap(MenuContentView(monitor: monitor, live: monitor.live, tracker: tracker, onOpen: { _ in })
                    .defaultAppStorage(store), size: nil, dark: dark)
                save(framed(popover, dark: dark, radius: 12), "popover-\(range.lowercased())-\(mode)")
            }

            for section in MainSection.allCases {
                store.set(section.rawValue, forKey: MainSection.storageKey)
                let shot = await snap(MainView(monitor: monitor, preferences: prefs, tracker: tracker)
                    .defaultAppStorage(store), size: CGSize(width: 1100, height: section == .today ? 1000 : 1140), dark: dark)
                let window = framed(shot, dark: dark, radius: 12, trafficLights: true)
                save(window, "\(section.rawValue)-\(mode)")
                if section == .today { todayWindow[dark] = window }
            }

            // The alert over a desktop with the Today window on it.
            let desk = desktop(window: todayWindow[dark]!, dark: dark)
            save(composite(desk, glow: 0.95, reach: 1, caption: "Xcode"), "alert-\(mode)")
            let cardSize = CGSize(width: 580, height: 560) // the reset panel's fixed frame
            let card = await snap(InterruptView(onClose: {}, onGlow: { _, _ in }), size: cardSize, dark: dark, transparent: true)
            save(composite(desk, glow: 0.8, scrim: 0.42, card: card), "reset-prompt-\(mode)")
            let resetCard = await snap(InterruptView(onClose: {}, onGlow: { _, _ in }, phase: .reset, remaining: 17),
                                       size: cardSize, dark: dark, transparent: true)
            save(composite(desk, glow: 0.38, scrim: 0.42, card: resetCard), "reset-breathing-\(mode)")
        }

        for dark in [false, true] { save(dockAndMenuBar(dark: dark), "icon-in-dock-\(dark ? "dark" : "light")") }
        save(NSApp.applicationIconImage, "icon-1024", scale: 1024 / NSApp.applicationIconImage.size.width)

        // Frames of the level-1 glow at 30 fps, 0.2 s before it starts to 0.3 s after it ends, for the video and strip.
        let desk = desktop(window: todayWindow[false]!, dark: false)
        for (i, t) in stride(from: -0.2, through: GlowTimeline.duration + 0.3, by: 1.0 / 30).enumerated() {
            let level = GlowTimeline.level(at: t, reduceMotion: false)
            save(composite(desk, glow: level, reach: GlowTimeline.reach(at: t, reduceMotion: false), caption: "Xcode", scale: 1), String(format: "frames/%03d", i), scale: 1)
        }
        try? Chime.signalWAV.write(to: out.appendingPathComponent("chime.wav"))
        print("DesignShots done")
    }

    // MARK: Rendering

    private static func snap<V: View>(_ view: V, size: CGSize?, dark: Bool, transparent: Bool = false) async -> NSImage {
        let host = NSHostingView(rootView: view)
        host.appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
        let fitting = size ?? host.fittingSize
        let window = NSWindow(contentRect: NSRect(x: -30000, y: 0, width: fitting.width, height: fitting.height),
                              styleMask: [.borderless], backing: .buffered, defer: false)
        window.appearance = host.appearance
        window.isOpaque = false
        window.backgroundColor = transparent ? .clear : NSColor(Color.dsBackground)
        window.contentView = host
        window.orderFrontRegardless()
        try? await Task.sleep(for: .milliseconds(700))
        host.layoutSubtreeIfNeeded()
        let rep = bitmap(host.bounds.size, scale: 2)
        host.cacheDisplay(in: host.bounds, to: rep)
        window.orderOut(nil)
        let image = NSImage(size: host.bounds.size)
        image.addRepresentation(rep)
        return image
    }

    /// Rounded corners, a hairline, a soft shadow and (for windows) the three window controls.
    private static func framed(_ image: NSImage, dark: Bool, radius: CGFloat, trafficLights: Bool = false) -> NSImage {
        let pad: CGFloat = 48
        let size = CGSize(width: image.size.width + pad * 2, height: image.size.height + pad * 2)
        return NSImage(size: size, flipped: false) { _ in
            let rect = NSRect(x: pad, y: pad, width: image.size.width, height: image.size.height)
            let path = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
            NSGraphicsContext.saveGraphicsState()
            let shadow = NSShadow()
            shadow.shadowColor = .black.withAlphaComponent(dark ? 0.55 : 0.18)
            shadow.shadowBlurRadius = 30
            shadow.shadowOffset = NSSize(width: 0, height: -10)
            shadow.set()
            NSColor.black.setFill()
            path.fill()
            NSGraphicsContext.restoreGraphicsState()
            NSGraphicsContext.saveGraphicsState()
            path.addClip()
            image.draw(in: rect)
            NSGraphicsContext.restoreGraphicsState()
            (dark ? NSColor.white.withAlphaComponent(0.14) : NSColor.black.withAlphaComponent(0.12)).setStroke()
            path.lineWidth = 1
            path.stroke()
            if trafficLights {
                for (i, hex) in [0xFF5F57, 0xFEBC2E, 0x28C840].enumerated() {
                    NSColor(hex: UInt32(hex)).setFill()
                    NSBezierPath(ovalIn: NSRect(x: rect.minX + 14 + CGFloat(i) * 20, y: rect.maxY - 26, width: 12, height: 12)).fill()
                }
            }
            return true
        }
    }

    /// A 14" display: plain wallpaper, a menu bar, the window in the middle.
    private static let screen = CGSize(width: 1512, height: 982)

    private static func desktop(window: NSImage, dark: Bool) -> NSImage {
        NSImage(size: screen, flipped: false) { rect in
            let wall = NSGradient(starting: NSColor(hex: dark ? 0x1D2230 : 0xB9C3CF), ending: NSColor(hex: dark ? 0x2B2A35 : 0xDCD9D3))!
            wall.draw(in: rect, angle: -70)
            let scale = min(1, (rect.height - 80) / window.size.height)
            let w = window.size.width * scale, h = window.size.height * scale
            window.draw(in: NSRect(x: rect.midX - w / 2, y: (rect.height - 24 - h) / 2, width: w, height: h))
            (dark ? NSColor.black.withAlphaComponent(0.35) : NSColor.white.withAlphaComponent(0.55)).setFill()
            NSRect(x: 0, y: rect.height - 24, width: rect.width, height: 24).fill()
            let attrs: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 13, weight: .medium),
                                                       .foregroundColor: dark ? NSColor.white : NSColor.black]
            ("Xcode      File      Edit      View      Product      Window" as NSString)
                .draw(at: NSPoint(x: 40, y: rect.height - 19), withAttributes: attrs)
            return true
        }
    }

    /// The icon in a Dock between familiar apps, and the template glyph in a menu bar, watching and paused.
    private static func dockAndMenuBar(dark: Bool) -> NSImage {
        let size = CGSize(width: 760, height: 300)
        let ids = ["com.apple.finder", "com.apple.Safari", "com.apple.mail", "com.apple.dt.Xcode", "com.apple.Notes"]
        let others = ids.compactMap { NSWorkspace.shared.urlForApplication(withBundleIdentifier: $0) }
            .map { NSWorkspace.shared.icon(forFile: $0.path) }
        return NSImage(size: size, flipped: false) { rect in
            NSGradient(starting: NSColor(hex: dark ? 0x1D2230 : 0xB9C3CF), ending: NSColor(hex: dark ? 0x2B2A35 : 0xDCD9D3))!
                .draw(in: rect, angle: -70)
            let ink = dark ? NSColor.white : NSColor.black

            // Menu bar with the glyph, watching then paused
            (dark ? NSColor.black.withAlphaComponent(0.35) : NSColor.white.withAlphaComponent(0.55)).setFill()
            NSRect(x: 0, y: rect.height - 24, width: rect.width, height: 24).fill()
            let attrs: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 13, weight: .medium), .foregroundColor: ink]
            ("Fri 27 Nov  23:40" as NSString).draw(at: NSPoint(x: rect.width - 130, y: rect.height - 19), withAttributes: attrs)
            for (i, running) in [true, false].enumerated() {
                let glyph = MenuGlyph.image(running: running)
                let tinted = NSImage(size: glyph.size, flipped: false) { r in
                    glyph.draw(in: r); ink.set(); r.fill(using: .sourceAtop); return true
                }
                tinted.draw(in: NSRect(x: rect.width - 186 + CGFloat(i) * 28, y: rect.height - 21, width: 16, height: 18))
            }

            // Dock
            let mine: NSImage = NSApp.applicationIconImage
            let icons: [NSImage] = Array(others.prefix(3)) + [mine] + Array(others.dropFirst(3))
            let side: CGFloat = 72, gap: CGFloat = 6
            let width = CGFloat(icons.count) * side + CGFloat(icons.count - 1) * gap + 20
            let dock = NSRect(x: rect.midX - width / 2, y: 40, width: width, height: side + 20)
            let shape = NSBezierPath(roundedRect: dock, xRadius: 22, yRadius: 22)
            (dark ? NSColor.black.withAlphaComponent(0.3) : NSColor.white.withAlphaComponent(0.35)).setFill()
            shape.fill()
            (dark ? NSColor.white.withAlphaComponent(0.14) : NSColor.white.withAlphaComponent(0.5)).setStroke()
            shape.stroke()
            for (i, icon) in icons.enumerated() {
                let x = dock.minX + 10 + CGFloat(i) * (side + gap)
                icon.draw(in: NSRect(x: x, y: dock.minY + 10, width: side, height: side))
                if icon === mine {
                    ink.withAlphaComponent(0.7).setFill()
                    NSBezierPath(ovalIn: NSRect(x: x + side / 2 - 2, y: dock.minY + 3, width: 4, height: 4)).fill()
                }
            }
            // The large icon above
            mine.draw(in: NSRect(x: rect.midX - 70, y: dock.maxY + 4, width: 140, height: 140))
            return true
        }
    }

    private static func composite(_ desk: NSImage, glow level: Double, reach: Double? = nil, scrim: Double = 0, caption: String? = nil,
                                  card: NSImage? = nil, scale: CGFloat = 2) -> NSImage {
        let glow = EdgeGlowView(frame: NSRect(origin: .zero, size: screen))
        glow.setCaption(caption.map { EdgeGlowView.captionImage(app: $0) } ?? nil)
        glow.apply(level: level, reach: reach, scrim: scrim)
        let rep = bitmap(screen, scale: scale)
        NSGraphicsContext.saveGraphicsState()
        let ctx = NSGraphicsContext(bitmapImageRep: rep)!
        NSGraphicsContext.current = ctx
        desk.draw(in: NSRect(origin: .zero, size: screen))
        glow.layer!.render(in: ctx.cgContext)
        if let card {
            card.draw(in: NSRect(x: (screen.width - card.size.width) / 2, y: (screen.height - card.size.height) / 2,
                                 width: card.size.width, height: card.size.height))
        }
        NSGraphicsContext.restoreGraphicsState()
        let image = NSImage(size: screen)
        image.addRepresentation(rep)
        return image
    }

    private static func bitmap(_ size: CGSize, scale: CGFloat) -> NSBitmapImageRep {
        let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(size.width * scale), pixelsHigh: Int(size.height * scale),
                                   bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                   colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        rep.size = size
        return rep
    }

    /// Rasterizes at `scale` (2x by default, like a Retina screenshot) and writes a PNG.
    private static func save(_ image: NSImage, _ name: String, scale: CGFloat = 2) {
        let rep = bitmap(image.size, scale: scale)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        image.draw(in: NSRect(origin: .zero, size: image.size))
        NSGraphicsContext.restoreGraphicsState()
        try? rep.representation(using: .png, properties: [:])?.write(to: out.appendingPathComponent(name + ".png"))
    }

    // MARK: Mock history: 95 days, improving, with afternoon peaks and a few apps that lead.

    private static func mockTracker() -> HabitTracker {
        var rng = SystemRandomNumberGenerator.Seeded(7)
        let cal = Calendar.current
        let now = Date()
        let today = cal.startOfDay(for: now)
        let apps: [(String?, String?, Double)] = [("Xcode", "com.apple.dt.Xcode", 30), ("Safari", "com.apple.Safari", 24),
                                                  ("Zoom", "us.zoom.xos", 15), ("Slack", "com.tinyspeck.slackmacgap", 12),
                                                  ("Mail", "com.apple.mail", 9), ("Notes", "com.apple.Notes", 6), (nil, nil, 4)]
        func pickApp() -> (String?, String?) {
            var r = rng.unit() * apps.map(\.2).reduce(0, +)
            for a in apps { r -= a.2; if r <= 0 { return (a.0, a.1) } }
            return (apps[0].0, apps[0].1)
        }
        var records: [Detection] = []
        var active = Set<Date>()
        func episode(at start: Date) {
            let (name, id) = pickApp()
            for k in 0..<(1 + Int(rng.unit() * 6)) {
                records.append(Detection(date: start.addingTimeInterval(Double(k) * 2.2), app: name, bundleID: id))
            }
        }
        for back in stride(from: 95, through: 1, by: -1) {
            let day = cal.date(byAdding: .day, value: -back, to: today)!
            let weekday = cal.component(.weekday, from: day)
            if (weekday == 1 || weekday == 7) && rng.unit() < 0.55 { continue } // weekends often off
            active.insert(day)
            let lambda = (1.6 + 3.4 * Double(back) / 95) * ([3, 5].contains(weekday) ? 1.35 : 1)
            var n = 0, p = exp(-lambda), s = p, u = rng.unit()
            while u > s { n += 1; p *= lambda / Double(n); s += p }
            for _ in 0..<n {
                let u = rng.unit()
                let hour = u < 0.3 ? 10 + rng.unit() * 2 : u < 0.75 ? 14 + rng.unit() * 2.5 : 20 + rng.unit() * 2.5
                episode(at: day.addingTimeInterval(hour * 3600))
            }
        }
        active.insert(today)
        for ago in [7.6, 5.1, 2.25] { // three today, the last one a little over two hours ago
            episode(at: max(today.addingTimeInterval(600 * ago), now.addingTimeInterval(-ago * 3600)))
        }
        return HabitTracker(mockRecords: records.sorted { $0.date < $1.date }, activeDays: active)
    }
}

private extension SystemRandomNumberGenerator {
    /// Deterministic SplitMix64, so the screenshots are the same every run.
    struct Seeded {
        var state: UInt64
        init(_ seed: UInt64) { state = seed }
        mutating func unit() -> Double {
            state &+= 0x9E3779B97F4A7C15
            var z = state
            z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
            z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
            return Double((z ^ (z >> 31)) >> 11) / Double(1 << 53)
        }
    }
}
#endif
