import Foundation
import CoreML
import CoreImage
import CoreVideo

/// Runs a NailBiteClassifier model on camera frames.
///
/// The models (exported by NBDetect's export_coreml_image.py) take an RGB image and do the
/// ImageNet normalization themselves, and output `p_biting` directly. All this class does is
/// fit the camera frame to the model's input size the way training did: scale to cover, then
/// center-crop (training frames were 1280x720, resized on the short side).
final class ModelRunner {
    private let model: MLModel
    private let width: Int
    private let height: Int
    private let context = CIContext(options: [.cacheIntermediates: false])
    private var pool: CVPixelBufferPool?

    convenience init(mlpackageName: String) throws {
        guard let url = Bundle.main.url(forResource: mlpackageName, withExtension: "mlmodelc")
                ?? Bundle.main.url(forResource: mlpackageName, withExtension: "mlpackage") else {
            throw NSError(domain: "ModelRunner", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "Model \(mlpackageName) not found"])
        }
        try self.init(url: url)
    }

    init(url: URL) throws {
        let config = MLModelConfiguration()
        config.computeUnits = .all  // picks the Neural Engine on Apple silicon
        model = try MLModel(contentsOf: url, configuration: config)

        guard let constraint = model.modelDescription.inputDescriptionsByName["image"]?.imageConstraint else {
            throw NSError(domain: "ModelRunner", code: -2,
                          userInfo: [NSLocalizedDescriptionKey: "Model has no image input named \"image\""])
        }
        width = constraint.pixelsWide
        height = constraint.pixelsHigh

        let attrs: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: width,
            kCVPixelBufferHeightKey as String: height,
            kCVPixelBufferIOSurfacePropertiesKey as String: [:],
            kCVPixelBufferMetalCompatibilityKey as String: true,
        ]
        CVPixelBufferPoolCreate(nil, nil, attrs as CFDictionary, &pool)
    }

    /// Probability that the frame shows nail-biting, or nil if inference failed.
    func predict(pixelBuffer: CVPixelBuffer) -> Double? {
        guard let input = fit(pixelBuffer),
              let features = try? MLDictionaryFeatureProvider(dictionary: ["image": MLFeatureValue(pixelBuffer: input)]),
              let output = try? model.prediction(from: features),
              let p = output.featureValue(for: "p_biting")?.multiArrayValue
        else { return nil }
        return p[0].doubleValue
    }

    /// Aspect-fill: scale so the frame covers the model input, then crop the center.
    private func fit(_ source: CVPixelBuffer) -> CVPixelBuffer? {
        guard let pool else { return nil }
        var out: CVPixelBuffer?
        CVPixelBufferPoolCreatePixelBuffer(nil, pool, &out)
        guard let out else { return nil }

        let image = CIImage(cvPixelBuffer: source)
        let scale = max(CGFloat(width) / image.extent.width, CGFloat(height) / image.extent.height)
        let scaled = image.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        let dx = (scaled.extent.width - CGFloat(width)) / 2
        let dy = (scaled.extent.height - CGFloat(height)) / 2
        let cropped = scaled.transformed(by: CGAffineTransform(translationX: -dx, y: -dy))
        context.render(cropped, to: out, bounds: CGRect(x: 0, y: 0, width: width, height: height),
                       colorSpace: CGColorSpace(name: CGColorSpace.sRGB))
        return out
    }
}
