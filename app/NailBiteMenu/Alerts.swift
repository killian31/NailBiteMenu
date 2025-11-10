import AppKit
import UserNotifications

enum Alerts {
    private static let defaults = UserDefaults.standard
    private static let muteKey = "alertsMuted"

    static func configure() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }

    static func setMuted(_ muted: Bool) {
        defaults.set(muted, forKey: muteKey)
    }

    static var isMuted: Bool {
        defaults.bool(forKey: muteKey)
    }

    static func postDetectionAlert(confidence: Double) {
        let content = UNMutableNotificationContent()
        content.title = "Nail-biting detected"
        content.body = String(format: "Confidence: %.0f%%", confidence * 100)
        content.sound = isMuted ? nil : UNNotificationSound.defaultCriticalSound(withAudioVolume: 1.0)
        let req = UNNotificationRequest(identifier: UUID().uuidString,
                                        content: content,
                                        trigger: UNTimeIntervalNotificationTrigger(timeInterval: 0.1, repeats: false))
        UNUserNotificationCenter.current().add(req)

        playChimeIfNeeded()
        Overlay.show(message: content.title + "\n" + content.body)
    }

    private static func playChimeIfNeeded() {
        guard !isMuted else { return }
        if let sound = NSSound(named: NSSound.Name("Basso")) {
            sound.volume = 1.0
            sound.play()
        } else {
            NSSound.beep()
        }
    }
}
