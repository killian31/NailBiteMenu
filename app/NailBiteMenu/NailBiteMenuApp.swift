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

    }

    var body: some Scene {
        Window("NailBite", id: "home") {
            MainView(monitor: monitor, preferences: preferences, tracker: tracker)
        }
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
        // Template symbol: macOS tints it to match the menu bar, like every native item.
        Image(systemName: isRunning ? "hand.raised.fill" : "hand.raised.slash")
            .accessibilityLabel(isRunning ? "NailBite, monitoring" : "NailBite, paused")
    }
}
