import SwiftUI
import AppKit

@main
struct NailBiteMenuApp: App {
    @StateObject private var preferences: AppPreferences
    @StateObject private var monitor: MonitorViewModel
    @StateObject private var tracker: HabitTracker

    init() {
        let prefs = AppPreferences()
        let tracker = HabitTracker()
        
        _preferences = StateObject(wrappedValue: prefs)
        _tracker = StateObject(wrappedValue: tracker)
        
        _monitor = StateObject(wrappedValue: MonitorViewModel(preferences: prefs, tracker: tracker))

        DispatchQueue.main.async {
            // Synthesize the chimes and build the glow panels now, so the first alert starts on time.
            _ = Chime.signal
            AlertPresenter.prepare()
            #if DEBUG
            DesignShots.runIfRequested()
            #endif
        }
    }

    var body: some Scene {
        Window("NailBite", id: "home") {
            MainView(monitor: monitor, preferences: preferences, tracker: tracker)
        }
        .windowStyle(.hiddenTitleBar)
        .commands {
            AppTerminationCommands()
        }

        Settings {
            SettingsView(preferences: preferences, tracker: tracker, monitor: monitor)
                .frame(width: 520, height: 720)
        }

        MenuBarExtra {
            MenuBarPanel(monitor: monitor, live: monitor.live, tracker: tracker)
        } label: {
            MenuBarStatus(isRunning: monitor.isRunning)
        }
        .menuBarExtraStyle(.window)
    }
}

private struct MenuBarPanel: View {
    let monitor: MonitorViewModel
    let live: LiveStats
    let tracker: HabitTracker
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismiss) private var dismiss
    @AppStorage(MainSection.storageKey) private var section: MainSection = .today

    var body: some View {
        MenuContentView(monitor: monitor, live: live, tracker: tracker) { target in
            section = target
            dismiss()
            presentHomeWindow(using: openWindow)
        }
    }
}

private struct AppTerminationCommands: Commands {
    var body: some Commands {
        CommandGroup(replacing: .appTermination) {
            Button("Close NailBite App") {
                collapseAppToMenuBar()
            }
            .keyboardShortcut("q", modifiers: [.command])

            Button("Quit NailBite Completely") {
                NSApp.terminate(nil)
            }
            .keyboardShortcut("q", modifiers: [.command, .shift])
        }
    }
}

private struct MenuBarStatus: View {
    let isRunning: Bool

    var body: some View {
        // Template image: macOS tints it to match the menu bar, like every native item.
        Image(nsImage: MenuGlyph.image(running: isRunning))
            .accessibilityLabel(isRunning ? "NailBite, watching" : "NailBite, paused")
    }
}

/// The app icon's fingertip, drawn as an 18 pt template glyph: a finger outline with a solid nail,
/// slashed when paused.
enum MenuGlyph {
    private static let running = make(paused: false)
    private static let paused = make(paused: true)

    static func image(running isRunning: Bool) -> NSImage { isRunning ? running : paused }

    private static func make(paused: Bool) -> NSImage {
        let image = NSImage(size: NSSize(width: 16, height: 18), flipped: false) { _ in
            NSColor.black.set()
            let finger = NSBezierPath(roundedRect: NSRect(x: 3.25, y: -6, width: 9.5, height: 23.25), xRadius: 4.75, yRadius: 4.75)
            finger.lineWidth = 1.5
            finger.stroke()
            let nail = NSBezierPath(roundedRect: NSRect(x: 5.5, y: 8, width: 5, height: 7), xRadius: 2.5, yRadius: 2.5)
            nail.fill()
            if paused {
                let slash = NSBezierPath()
                slash.move(to: NSPoint(x: 1, y: 16.5))
                slash.line(to: NSPoint(x: 15, y: 1.5))
                slash.lineCapStyle = .round
                NSGraphicsContext.current?.compositingOperation = .clear // a gap on each side of the slash
                slash.lineWidth = 4
                slash.stroke()
                NSGraphicsContext.current?.compositingOperation = .sourceOver
                slash.lineWidth = 1.5
                slash.stroke()
            }
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = paused ? "NailBite, paused" : "NailBite, watching"
        return image
    }
}
