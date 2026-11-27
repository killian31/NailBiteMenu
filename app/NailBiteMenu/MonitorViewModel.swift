import Foundation
import Combine
import CoreVideo
import Darwin.Mach
import AppKit

/// Values that change several times a second. Kept off `MonitorViewModel` so windows that only
/// need `isRunning` don't re-render on every camera frame; only the menu panel observes this.
final class LiveStats: ObservableObject {
    @Published var confidence: Double = 0
    @Published var fps: Double = 0
    @Published var cpuPercent: Double = 0
    @Published var memoryMB: Double = 0
}

final class MonitorViewModel: ObservableObject {
    private let preferences: AppPreferences
    private let tracker: HabitTracker
    private var cancellables = Set<AnyCancellable>()

    @Published var isRunning = false {
        didSet { isRunning ? start() : stop() }
    }
    @Published var thresholdPercent: Double = 75 {
            didSet {
                if abs(preferences.confidenceThreshold - thresholdPercent) > .ulpOfOne {
                    preferences.confidenceThreshold = thresholdPercent
                }
            }
        }
    let live = LiveStats()
    @Published private(set) var lastDetectionDate: Date?

    private let alpha: Double = 0.40
    private var threshold: Double {
            max(0.0, min(1.0, thresholdPercent / 100.0))
        }
    private var lastRecorded = Date.distantPast
    private var lastHit = Date.distantPast
    private var episodeStart = Date.distantPast
    private var escalated = false
    private let recordEvery: TimeInterval = 2
    // ponytail: fixed 8 s before escalating; expose in Settings if people want it tunable.
    private let escalateAfter: TimeInterval = 8
    private var ema: Double = 0.0
    @Published var showDebug: Bool = false
    private var statsTimer: Timer?
    private var lastInferAt: CFAbsoluteTime = CFAbsoluteTimeGetCurrent()
    private var fpsEMA: Double = 0

    private let camera = CameraPipeline()
    private var model: ModelRunner?

    init(preferences: AppPreferences, tracker: HabitTracker) {
        self.preferences = preferences
        self.tracker = tracker
        thresholdPercent = preferences.confidenceThreshold

        camera.onFrame = { [weak self] pb in
            guard let self, let model = self.model else { return }
            let t0 = CFAbsoluteTimeGetCurrent()
            if let p = model.predict(pixelBuffer: pb) {
                let dt = max(1e-6, CFAbsoluteTimeGetCurrent() - t0)
                let instFPS = 1.0 / dt
                self.fpsEMA = 0.85 * self.fpsEMA + 0.15 * instFPS
                let fps = self.fpsEMA
                DispatchQueue.main.async { if self.showDebug { self.live.fps = fps } }
                self.handle(prob: p)
            }
        }

        loadModel()
        bindPreferences()
        if preferences.startMonitoringOnLaunch {
            isRunning = true
        }
    }

    // ponytail: one model. 2.2.0 retrain adds look-alikes (vaping, pencil, cup) and biting from the
    // new Mac's camera, with a random-reframe augmentation. On NBDetect's test split this camera
    // scores ROC AUC 0.986 (2.1.0: 0.862). 0.5 ms/frame. Bring back a size setting only if needed.
    private static let modelName = "NailBiteClassifier_224"

    private func loadModel() {
        do {
            self.model = try ModelRunner(mlpackageName: Self.modelName)
            print("✅ Loaded model:", Self.modelName)
        } catch {
            print("❌ Model load error:", error)
            self.model = nil
        }
    }

    #if DEBUG
    /// Design screenshots: show the watching state without opening the camera.
    var screenshotMode = false
    #endif

    func start() {
        #if DEBUG
        if screenshotMode { return }
        #endif
        ema = 0
        live.confidence = 0
        camera.start()
        startStatsTimer()
    }

    func stop()  {
        camera.stop()
        ema = 0
        live.confidence = 0
        stopStatsTimer()
    }

    private func handle(prob: Double) {
        DispatchQueue.main.async {
            self.ema = (1 - self.alpha) * self.ema + self.alpha * prob
            let smoothed = max(0.0, min(1.0, self.ema))
            if abs(self.live.confidence - smoothed) >= 0.005 { self.live.confidence = smoothed }

            guard smoothed >= self.threshold else { return }
            self.registerHit(at: Date())
        }
    }
    
    /// One alert per episode: banner first, full-screen reset if biting continues.
    private func registerHit(at now: Date) {
        // Our own windows aren't a trigger worth reporting.
        let app = NSWorkspace.shared.frontmostApplication.flatMap { $0 == NSRunningApplication.current ? nil : $0 }
        if now.timeIntervalSince(lastHit) > Episode.gap {
            episodeStart = now
            escalated = false
            Alerts.gentle(app: app?.localizedName)
        } else if !escalated, preferences.interruptIfContinuing,
                  now.timeIntervalSince(episodeStart) >= escalateAfter {
            escalated = true
            Alerts.interrupt()
        }
        lastHit = now

        if now.timeIntervalSince(lastRecorded) >= recordEvery {
            lastRecorded = now
            lastDetectionDate = now
            tracker.addDetection(at: now, app: app?.localizedName, bundleID: app?.bundleIdentifier)
        }
    }

    private func startStatsTimer() {
        stopStatsTimer()
        statsTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.tracker.markActive()
            guard self.showDebug else { return }
            self.live.cpuPercent = Self.currentProcessCPU()
            self.live.memoryMB = Double(Self.currentResidentBytes()) / (1024.0 * 1024.0)
        }
        if let t = statsTimer { RunLoop.main.add(t, forMode: .common) }
    }

    private func stopStatsTimer() {
        statsTimer?.invalidate()
        statsTimer = nil
    }

    static func currentResidentBytes() -> UInt64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.stride) / 4
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        return kerr == KERN_SUCCESS ? info.resident_size : 0
    }

    static func currentProcessCPU() -> Double {
        var threadList: thread_act_array_t?
        var threadCount = mach_msg_type_number_t(0)
        guard task_threads(mach_task_self_, &threadList, &threadCount) == KERN_SUCCESS,
              let threads = threadList
        else { return 0 }

        var total: Double = 0
        for i in 0..<Int(threadCount) {
            var info = thread_basic_info()
            var count = mach_msg_type_number_t(THREAD_INFO_MAX)
            let kr = withUnsafeMutablePointer(to: &info) {
                $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                    thread_info(threads[i], thread_flavor_t(THREAD_BASIC_INFO), $0, &count)
                }
            }
            if kr == KERN_SUCCESS, (info.flags & TH_FLAGS_IDLE) == 0 {
                total += Double(info.cpu_usage) / Double(TH_USAGE_SCALE) * 100.0
            }
        }
        vm_deallocate(mach_task_self_, vm_address_t(bitPattern: threads), vm_size_t(threadCount) * vm_size_t(MemoryLayout<thread_t>.stride))
        return min(max(total, 0), 1000)
    }

    private func bindPreferences() {
        preferences.$confidenceThreshold
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newValue in
                guard let self, abs(self.thresholdPercent - newValue) > .ulpOfOne else { return }
                self.thresholdPercent = newValue
            }
            .store(in: &cancellables)
    }
}
