import SwiftUI
import AppKit

@MainActor
func restoreAndActivateApp() {
    NSApp.setActivationPolicy(.regular)
    NSApp.unhide(nil)
    focusApplication()
}

@MainActor
func presentHomeWindow(using openWindow: OpenWindowAction) {
    restoreAndActivateApp()
    openWindow(id: "home")
    bringHomeWindowToFront()
}

@MainActor
func collapseAppToMenuBar() {
    let protectedLevels: Set<NSWindow.Level> = [.statusBar, .popUpMenu]
    for window in NSApp.windows where window.isVisible && !protectedLevels.contains(window.level) {
        window.close()
    }
    NSApp.hide(nil)
    NSApp.setActivationPolicy(.accessory)
}

@MainActor
func presentSettingsWindow() {
    restoreAndActivateApp()
    let selectors = ["showSettingsWindow:", "showPreferencesWindow:"].map { NSSelectorFromString($0) }
    for selector in selectors {
        if NSApp.sendAction(selector, to: nil, from: nil) {
            focusApplication(after: 0.05)
            return
        }
    }
}

@MainActor
private func bringHomeWindowToFront() {
    focusApplication(after: 0.05) {
        if let window = NSApp.windows.first(where: { $0.title == "NailBite Home" }) {
            window.makeKeyAndOrderFront(nil)
            focusApplication()
        }
    }
}

@MainActor
private func focusApplication(after delay: TimeInterval = 0, _ completion: (() -> Void)? = nil) {
    let focusWork = {
        NSRunningApplication.current.activate()
        NSApp.activate()
        completion?()
    }
    guard delay > 0 else {
        focusWork()
        return
    }

    Task { @MainActor in
        let nanos = UInt64(max(0, delay) * 1_000_000_000)
        try? await Task.sleep(nanoseconds: nanos)
        focusWork()
    }
}

@MainActor
func presentSettingsScene(using openSettings: OpenSettingsAction) {
    restoreAndActivateApp()
    if #available(macOS 13.0, *) {
        openSettings()
    } else {
        presentSettingsWindow()
    }
}
