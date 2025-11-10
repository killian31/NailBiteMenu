import Foundation
import Combine
import CoreVideo
import Darwin.Mach

enum ModelVariant: String, CaseIterable, Identifiable {
    case m224 = "224"
    case m384 = "384"
    case m512 = "512"
    var id: String { rawValue }

    var displayName: String { "\(rawValue) px" }
    var imageSize: Int { Int(rawValue)! }
    var mlpackageName: String { "NailBiteClassifier_\(rawValue)" }
}

final class MonitorViewModel: ObservableObject {
    private let preferences: AppPreferences
    private let tracker: HabitTracker
    private var cancellables = Set<AnyCancellable>()

    @Published var isRunning = false {
        didSet { isRunning ? start() : stop() }
    }
    @Published var selectedVariant: ModelVariant = .m512 {
        didSet {
            guard oldValue != selectedVariant else { return }
            if preferences.modelVariant != selectedVariant {
                preferences.modelVariant = selectedVariant
            }
            loadModel(variant: selectedVariant)
        }
    }
    @Published var thresholdPercent: Double = 75 {
            didSet {
                if abs(preferences.confidenceThreshold - thresholdPercent) > .ulpOfOne {
                    preferences.confidenceThreshold = thresholdPercent
                }
            }
        }
    @Published private(set) var smoothedConfidence: Double = 0
    @Published private(set) var lastDetectionDate: Date?

    private let alpha: Double = 0.40
    private var threshold: Double {
            max(0.0, min(1.0, thresholdPercent / 100.0))
        }
    private var lastAlert = Date.distantPast
    private var cooldownSec: TimeInterval = 2
    private var ema: Double = 0.0
    @Published var showDebug: Bool = false
    @Published private(set) var fps: Double = 0
    @Published private(set) var cpuPercent: Double = 0
    @Published private(set) var memoryMB: Double = 0
    private var statsTimer: Timer?
    private var lastInferAt: CFAbsoluteTime = CFAbsoluteTimeGetCurrent()
    private var fpsEMA: Double = 0

    private let camera = CameraPipeline()
    private var model: ModelRunner?

    init(preferences: AppPreferences, tracker: HabitTracker) {
        self.preferences = preferences
        self.tracker = tracker
        selectedVariant = preferences.modelVariant
        thresholdPercent = preferences.confidenceThreshold

        camera.onFrame = { [weak self] pb in
            guard let self, let model = self.model else { return }
            let t0 = CFAbsoluteTimeGetCurrent()
            if let p = model.predict(pixelBuffer: pb) {
                let dt = max(1e-6, CFAbsoluteTimeGetCurrent() - t0)
                let instFPS = 1.0 / dt
                self.fpsEMA = 0.85 * self.fpsEMA + 0.15 * instFPS
                DispatchQueue.main.async { self.fps = self.fpsEMA }
                self.handle(prob: p)
            }
        }

        loadModel(variant: selectedVariant)
        bindPreferences()
        if preferences.startMonitoringOnLaunch {
            isRunning = true
        }
    }

    private func loadModel(variant: ModelVariant) {
        do {
            self.model = try ModelRunner(
                mlpackageName: variant.mlpackageName,
                imageSize: variant.imageSize,
                positiveIsBiting: false,
                outputsAreProbabilities: false
            )
            print("✅ Loaded model:", variant.mlpackageName)
        } catch {
            print("❌ Model load error:", error)
            self.model = nil
        }
    }

    func start() {
        ema = 0
        smoothedConfidence = 0
        camera.start()
        startStatsTimer()
    }

    func stop()  {
        camera.stop()
        ema = 0
        smoothedConfidence = 0
        stopStatsTimer()
    }

    private func handle(prob: Double) {
        DispatchQueue.main.async {
            self.ema = (1 - self.alpha) * self.ema + self.alpha * prob
            let smoothed = max(0.0, min(1.0, self.ema))
            self.smoothedConfidence = smoothed

            if smoothed >= self.threshold, Date().timeIntervalSince(self.lastAlert) >= self.cooldownSec {
                self.lastAlert = Date()
                self.lastDetectionDate = self.lastAlert
                Alerts.postDetectionAlert(confidence: smoothed)
                self.tracker.addDetection(at: self.lastAlert)
            }
        }
    }
    
    private func startStatsTimer() {
        stopStatsTimer()
        statsTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.cpuPercent = Self.currentProcessCPU()
            self.memoryMB   = Double(Self.currentResidentBytes()) / (1024.0 * 1024.0)
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
        preferences.$modelVariant
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newVariant in
                guard let self, self.selectedVariant != newVariant else { return }
                self.selectedVariant = newVariant
            }
            .store(in: &cancellables)

        preferences.$confidenceThreshold
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newValue in
                guard let self, abs(self.thresholdPercent - newValue) > .ulpOfOne else { return }
                self.thresholdPercent = newValue
            }
            .store(in: &cancellables)
    }
}
