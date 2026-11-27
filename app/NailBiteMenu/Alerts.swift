import AppKit

@MainActor
enum Alerts {
    static var isMuted = false

    /// First detection of an episode: banner + soft sound.
    static func gentle(app: String?) {
        play("Glass")
        AlertPresenter.showBanner(app: app)
    }

    /// Biting kept going after the banner: full-screen interrupt.
    static func interrupt() {
        play("Basso")
        AlertPresenter.showInterrupt()
    }

    private static func play(_ name: String) {
        guard !isMuted else { return }
        (NSSound(named: NSSound.Name(name)) ?? NSSound(named: NSSound.Name("Basso")))?.play()
    }
}
