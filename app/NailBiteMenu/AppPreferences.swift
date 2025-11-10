import Foundation
import Combine

final class AppPreferences: ObservableObject {
    private enum StorageKey {
        static let modelVariant = "preferences.modelVariant"
        static let threshold = "preferences.threshold"
        static let muteAlerts = "preferences.muteAlerts"
        static let startMonitoring = "preferences.startMonitoringOnLaunch"
    }

    private let defaults = UserDefaults.standard

    @Published var modelVariant: ModelVariant {
        didSet {
            guard oldValue != modelVariant else { return }
            defaults.set(modelVariant.rawValue, forKey: StorageKey.modelVariant)
        }
    }

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
            Alerts.setMuted(muteAlerts)
        }
    }

    @Published var startMonitoringOnLaunch: Bool {
        didSet {
            guard oldValue != startMonitoringOnLaunch else { return }
            defaults.set(startMonitoringOnLaunch, forKey: StorageKey.startMonitoring)
        }
    }

    init() {
        if let raw = defaults.string(forKey: StorageKey.modelVariant),
           let stored = ModelVariant(rawValue: raw) {
            modelVariant = stored
        } else {
            modelVariant = .m512
        }

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

        Alerts.setMuted(muteAlerts)
    }
}
