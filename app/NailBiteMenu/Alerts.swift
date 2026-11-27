import AppKit
import AVFoundation
import QuartzCore

@MainActor
enum Alerts {
    static var isMuted = false
    /// The two visible parts of the level-1 alert, each optional (Settings › Alert).
    static var showEdges = true
    static var showLabel = true

    /// How far ahead both the sound and the glow are scheduled, so they can start on the same frame.
    /// Two display frames: enough for the prebuilt panels to come forward and the audio device to start.
    private static let lead: TimeInterval = 0.03

    /// First detection of an episode: edge glow + chime.
    static func gentle(app: String?) {
        AlertPresenter.showGlow(app: app, edges: showEdges, label: showLabel) { schedule(Chime.signal) }
    }

    /// Every later detection in the episode: the edges stay lit while biting goes on. No sound.
    static func hold() {
        AlertPresenter.holdGlow(edges: showEdges)
    }

    /// Biting kept going after the glow: the hands-down reset.
    static func interrupt() {
        AlertPresenter.showInterrupt(edges: showEdges) { schedule(Chime.reset) }
    }

    /// Schedules the sound `lead` seconds out and returns the matching Core Animation start time.
    private static func schedule(_ player: AVAudioPlayer?) -> CFTimeInterval {
        let start = CACurrentMediaTime() + lead
        if !isMuted, let player {
            player.stop()
            player.currentTime = 0
            player.play(atTime: player.deviceCurrentTime + lead)
        }
        return start
    }
}

/// The alert sounds, synthesized once at launch so there is no file to load and no decode delay.
/// ponytail: two short sine chimes with a 2 ms attack; swap for recorded samples if they ever feel thin.
@MainActor
enum Chime {
    /// A bright, dry ping: E6 with a soft octave. Over in a quarter second.
    static let signalWAV = wav(notes: [(0, 1318.5)], decay: 0.11, length: 0.45, gain: 0.32)
    static let signal = player(signalWAV)
    /// Two lower notes falling a fourth: "hands down".
    static let resetWAV = wav(notes: [(0, 880.0), (0.14, 659.3)], decay: 0.16, length: 0.7, gain: 0.3)
    static let reset = player(resetWAV)

    private static func player(_ data: Data) -> AVAudioPlayer? {
        let player = try? AVAudioPlayer(data: data)
        player?.prepareToPlay()
        return player
    }

    private static func wav(notes: [(start: Double, freq: Double)], decay: Double, length: Double, gain: Double) -> Data {
        let rate = 44_100.0
        let count = Int(rate * length)
        var pcm = [Int16](repeating: 0, count: count)
        for i in 0..<count {
            let t = Double(i) / rate
            var s = 0.0
            for note in notes where t >= note.start {
                let u = t - note.start
                let env = min(1, u / 0.002) * exp(-u / decay)
                s += env * (sin(2 * .pi * note.freq * u) + 0.28 * sin(4 * .pi * note.freq * u) + 0.08 * sin(6 * .pi * note.freq * u))
            }
            pcm[i] = Int16(max(-1, min(1, s * gain)) * Double(Int16.max))
        }
        return wav(pcm, rate: Int(rate))
    }

    private static func wav(_ samples: [Int16], rate: Int) -> Data {
        var d = Data()
        func put<T: FixedWidthInteger>(_ v: T) { withUnsafeBytes(of: v.littleEndian) { d.append(contentsOf: $0) } }
        let bytes = samples.count * 2
        d.append(contentsOf: Array("RIFF".utf8)); put(UInt32(36 + bytes))
        d.append(contentsOf: Array("WAVEfmt ".utf8)); put(UInt32(16)); put(UInt16(1)); put(UInt16(1))
        put(UInt32(rate)); put(UInt32(rate * 2)); put(UInt16(2)); put(UInt16(16))
        d.append(contentsOf: Array("data".utf8)); put(UInt32(bytes))
        samples.forEach { put($0) }
        return d
    }
}
