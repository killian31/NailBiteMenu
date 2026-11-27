import Foundation
import Combine

final class AppPreferences: ObservableObject {
    private enum StorageKey {
        static let threshold = "preferences.threshold"
        static let muteAlerts = "preferences.muteAlerts"
        static let startMonitoring = "preferences.startMonitoringOnLaunch"
        static let interrupt = "preferences.interruptIfContinuing"
        static let appearance = "preferences.appearance"
        static let alertEdges = "preferences.alertEdges"
        static let alertLabel = "preferences.alertLabel"
    }

    private let defaults = UserDefaults.standard

    @Published var confidenceThreshold: Double {
        didSet {
            guard abs(oldValue - confidenceThreshold) > .ulpOfOne else { return }
            defaults.set(confidenceThreshold, forKey: StorageKey.threshold)
        }
    }

    @Published var muteAlerts: Bool {
        didSet {
            guard oldValue != muteAlerts else { return }
            defaults.set(muteAlerts, forKey: StorageKey.muteAlerts)
            Alerts.isMuted = muteAlerts
        }
    }

    /// Level-1 alert parts. The sound is `muteAlerts`.
    @Published var alertEdges: Bool {
        didSet { defaults.set(alertEdges, forKey: StorageKey.alertEdges); Alerts.showEdges = alertEdges }
    }
    @Published var alertLabel: Bool {
        didSet { defaults.set(alertLabel, forKey: StorageKey.alertLabel); Alerts.showLabel = alertLabel }
    }

    @Published var appearance: AppAppearance {
        didSet {
            defaults.set(appearance.rawValue, forKey: StorageKey.appearance)
            appearance.apply()
        }
    }

    /// Escalate to the full-screen reset when biting continues after the banner.
    @Published var interruptIfContinuing: Bool {
        didSet { defaults.set(interruptIfContinuing, forKey: StorageKey.interrupt) }
    }

    @Published var startMonitoringOnLaunch: Bool {
        didSet {
            guard oldValue != startMonitoringOnLaunch else { return }
            defaults.set(startMonitoringOnLaunch, forKey: StorageKey.startMonitoring)
        }
    }

    init() {
        defaults.removeObject(forKey: "preferences.modelVariant") // setting removed in 2.2

        if defaults.object(forKey: StorageKey.threshold) != nil {
            confidenceThreshold = defaults.double(forKey: StorageKey.threshold)
        } else {
            confidenceThreshold = 75
        }

        if defaults.object(forKey: StorageKey.muteAlerts) != nil {
            muteAlerts = defaults.bool(forKey: StorageKey.muteAlerts)
        } else {
            muteAlerts = false
        }

        if defaults.object(forKey: StorageKey.startMonitoring) != nil {
            startMonitoringOnLaunch = defaults.bool(forKey: StorageKey.startMonitoring)
        } else {
            startMonitoringOnLaunch = true
        }

        interruptIfContinuing = defaults.object(forKey: StorageKey.interrupt) as? Bool ?? true
        alertEdges = defaults.object(forKey: StorageKey.alertEdges) as? Bool ?? true
        alertLabel = defaults.object(forKey: StorageKey.alertLabel) as? Bool ?? true
        appearance = defaults.string(forKey: StorageKey.appearance).flatMap(AppAppearance.init) ?? .system
        let initial = appearance
        DispatchQueue.main.async { initial.apply() } // NSApp isn't ready during init

        Alerts.isMuted = muteAlerts
        Alerts.showEdges = alertEdges
        Alerts.showLabel = alertLabel
    }
}
