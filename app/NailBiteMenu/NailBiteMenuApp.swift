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
        
        Alerts.configure()
    }

    var body: some Scene {
        WindowGroup("NailBite Home", id: "home") {
            HomeView(monitor: monitor, preferences: preferences, tracker: tracker)
        }
        .commands {
            AppTerminationCommands()
        }

        Settings {
            SettingsView(preferences: preferences, tracker: tracker)
        }

        MenuBarExtra {
            MenuBarPanel(monitor: monitor, preferences: preferences)
        } label: {
            MenuBarStatus(isRunning: monitor.isRunning)
        }
        .menuBarExtraStyle(.window)
    }
}

private struct MenuBarPanel: View {
    @ObservedObject var monitor: MonitorViewModel
    @ObservedObject var preferences: AppPreferences
    @Environment(\.openWindow) private var openWindow
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        MenuContentView(
            monitor: monitor,
            preferences: preferences,
            onOpenApp: { presentHomeWindow(using: openWindow) },
            onOpenSettings: { openSettingsScene() }
        )
    }

    private func openSettingsScene() {
        presentSettingsScene(using: openSettings)
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
        Image(systemName: iconName)
            .symbolRenderingMode(.palette)
            .foregroundStyle(iconPrimaryColor, iconSecondaryColor)
    }

    private var iconName: String {
        "hand.raised.fill"
    }

    private var iconPrimaryColor: Color {
        isRunning ? .mint : .secondary
    }

    private var iconSecondaryColor: Color {
        isRunning ? .blue : .secondary.opacity(0.4)
    }
}
