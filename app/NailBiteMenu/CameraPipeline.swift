import Foundation
import AVFoundation
import AppKit

final class CameraPipeline: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    private let session = AVCaptureSession()
    private let output = AVCaptureVideoDataOutput()
    private let queue = DispatchQueue(label: "cam.infer.queue", qos: .utility)
    private let inflight = DispatchSemaphore(value: 1)
    private var input: AVCaptureDeviceInput?

    var onFrame: ((CVPixelBuffer) -> Void)?

    private var lastTick = CFAbsoluteTimeGetCurrent()
    private var frames = 0

    func configure(position: AVCaptureDevice.Position = .front) throws {
        session.beginConfiguration()
        session.sessionPreset = .vga640x480  // lower res = faster

        let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position)
            ?? AVCaptureDevice.default(for: .video)

        guard let device else { throw NSError(domain: "Camera", code: -1, userInfo: [NSLocalizedDescriptionKey: "No camera"]) }

        session.inputs.forEach { session.removeInput($0) }
        input = try AVCaptureDeviceInput(device: device)
        if session.canAddInput(input!) { session.addInput(input!) }

        output.alwaysDiscardsLateVideoFrames = true
        output.setSampleBufferDelegate(self, queue: queue)

        session.outputs.forEach { session.removeOutput($0) }
        if session.canAddOutput(output) {
            session.addOutput(output)
        }
        if let conn = output.connection(with: .video) {
            conn.videoMinFrameDuration = CMTime(value: 1, timescale: 5)
        }

        session.commitConfiguration()
    }

    func start() {
        AVCaptureDevice.requestAccess(for: .video) { granted in
            DispatchQueue.main.async {
                guard granted else { print("Camera permission denied"); return }
                if !self.session.isRunning {
                    do { try self.configure() } catch { print("Configure error:", error) }
                    self.session.startRunning()
                    self.lastTick = CFAbsoluteTimeGetCurrent()
                    self.frames = 0
                    print("Camera session started")
                }
            }
        }
    }

    func stop() {
        if session.isRunning {
            session.stopRunning()
            print("Camera session stopped")
        }
    }

    func captureOutput(_ output: AVCaptureOutput,
                       didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        guard inflight.wait(timeout: .now()) == .success else { return }
        defer { inflight.signal() }

        autoreleasepool {
            guard let pb = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
            onFrame?(pb)
        }
    }
}
