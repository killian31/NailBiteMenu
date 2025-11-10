import Foundation
import CoreML
import CoreVideo
import CoreImage
import Accelerate

final class ModelRunner {
    private let model: MLModel
    private let imageSize: Int
    private let ctx = CIContext(options: nil)

    private let mean: [Float] = [0.485, 0.456, 0.406]
    private let std:  [Float] = [0.229, 0.224, 0.225]

    private let positiveIsBiting: Bool
    private let outputsAreProbabilities: Bool
    private var resizePool: CVPixelBufferPool?
    private var scratchArray: MLMultiArray?
    private var planarR: [Float] = []
    private var planarG: [Float] = []
    private var planarB: [Float] = []
    private var r8: [UInt8] = []
    private var g8: [UInt8] = []
    private var b8: [UInt8] = []
    private var a8: [UInt8] = []
    private var argbBytes: [UInt8] = []
    
    init(mlpackageName: String,
         imageSize: Int,
         positiveIsBiting: Bool = true,
         outputsAreProbabilities: Bool = false) throws {

        let url =
            Bundle.main.url(forResource: mlpackageName, withExtension: "mlmodelc") ??
            Bundle.main.url(forResource: mlpackageName, withExtension: "mlpackage")

        guard let url else {
            throw NSError(domain: "ModelRunner", code: -1, userInfo: [NSLocalizedDescriptionKey: "Model file not found"])
        }

        let config = MLModelConfiguration()
        config.computeUnits = .all
        config.allowLowPrecisionAccumulationOnGPU = true
        self.model = try MLModel(contentsOf: url, configuration: config)
        self.imageSize = imageSize
        self.positiveIsBiting = positiveIsBiting
        self.outputsAreProbabilities = outputsAreProbabilities
        self.makePools(width: imageSize, height: imageSize)
    }
    
    private func makePools(width: Int, height: Int) {
        let attrs: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: width,
            kCVPixelBufferHeightKey as String: height,
            kCVPixelBufferIOSurfacePropertiesKey as String: [:],
            kCVPixelBufferMetalCompatibilityKey as String: true
        ]
        CVPixelBufferPoolCreate(nil, nil, attrs as CFDictionary, &resizePool)

        scratchArray = try? MLMultiArray(
            shape: [1, 3, NSNumber(value: height), NSNumber(value: width)],
            dataType: .float32
        )
        let n = width * height
        planarR = [Float](repeating: 0, count: n)
        planarG = [Float](repeating: 0, count: n)
        planarB = [Float](repeating: 0, count: n)
        r8 = [UInt8](repeating: 0, count: n)
        g8 = [UInt8](repeating: 0, count: n)
        b8 = [UInt8](repeating: 0, count: n)
        a8 = [UInt8](repeating: 0, count: n)
        argbBytes = [UInt8](repeating: 0, count: n * 4)
    }


    func predict(pixelBuffer: CVPixelBuffer) -> Double? {
        guard let resized = resizePixelBuffer(pixelBuffer, width: imageSize, height: imageSize) else { return nil }
        guard let array = nchwArray(from: resized, width: imageSize, height: imageSize) else { return nil }

        if let fp = try? MLDictionaryFeatureProvider(dictionary: ["input": array]),
           let out = try? model.prediction(from: fp) {
            return parseOutput(out)
        }
        if let fp = try? MLDictionaryFeatureProvider(dictionary: ["image": array]),
           let out = try? model.prediction(from: fp) {
            return parseOutput(out)
        }
        return nil
    }


    private func parseOutput(_ out: MLFeatureProvider) -> Double? {
        if let v = out.featureValue(for: "var_937")?.multiArrayValue {
            return probFromMultiArray(v)
        }
        for k in out.featureNames {
            if let v = out.featureValue(for: k)?.multiArrayValue {
                return probFromMultiArray(v)
            }
            if let dict = out.featureValue(for: k)?.dictionaryValue as? [String: NSNumber] {
                if let p = (dict["biting"] ?? dict["1"] ?? dict["true"])?.doubleValue {
                    return positiveIsBiting ? p : (1.0 - p)
                }
            }
        }
        return nil
    }

    private func probFromMultiArray(_ scores: MLMultiArray) -> Double {
        let n = scores.count
        var vals = (0..<n).map { scores[$0].doubleValue }

        if n == 1 {
            let p: Double
            if outputsAreProbabilities {
                p = min(max(vals[0], 0.0), 1.0)
            } else {
                let z = vals[0]
                p = 1.0 / (1.0 + exp(-z))
            }
            return positiveIsBiting ? p : (1.0 - p)
        }

        if !outputsAreProbabilities {
            // softmax
            let m = vals.max() ?? 0
            vals = vals.map { exp($0 - m) }
            let z = vals.reduce(0, +)
            if z > 0 { vals = vals.map { $0 / z } }
        }

        var bitingIndex = 1

        if let md = model.modelDescription.metadata[.creatorDefinedKey] as? [String:String],
           let csv = md["classes"] {
            let labels = csv.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces).lowercased() }
            if let idx = labels.firstIndex(of: "biting") { bitingIndex = idx }
        }

        let p = vals[min(max(bitingIndex, 0), vals.count - 1)]
        return positiveIsBiting ? p : (1.0 - p)
    }


    private func resizePixelBuffer(_ pb: CVPixelBuffer, width: Int, height: Int) -> CVPixelBuffer? {
        guard let pool = resizePool else { return nil }
        let ciImage = CIImage(cvPixelBuffer: pb)
        let scaleX = CGFloat(width) / ciImage.extent.width
        let scaleY = CGFloat(height) / ciImage.extent.height
        let scaled = ciImage.transformed(by: .init(scaleX: scaleX, y: scaleY))
        var dst: CVPixelBuffer?
        CVPixelBufferPoolCreatePixelBuffer(nil, pool, &dst)
        guard let dstPB = dst else { return nil }
        ctx.render(scaled, to: dstPB)
        return dstPB
    }

    private func nchwArray(from pb: CVPixelBuffer, width: Int, height: Int) -> MLMultiArray? {
        guard let arr = scratchArray else { return nil }
        
        CVPixelBufferLockBaseAddress(pb, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pb, .readOnly) }
        
        guard let base = CVPixelBufferGetBaseAddress(pb) else { return nil }
        var src = vImage_Buffer(
            data: base,
            height: vImagePixelCount(height),
            width:  vImagePixelCount(width),
            rowBytes: CVPixelBufferGetBytesPerRow(pb)
        )

        let argbStride = width * 4
        argbBytes.withUnsafeMutableBytes { bytes in
            var argb = vImage_Buffer(data: bytes.baseAddress,
                                     height: src.height,
                                     width:  src.width,
                                     rowBytes: argbStride)
            let map: [UInt8] = [3, 2, 1, 0]
            _ = map.withUnsafeBufferPointer { mp in
                vImagePermuteChannels_ARGB8888(&src, &argb, mp.baseAddress!, vImage_Flags(kvImageNoFlags))
            }
        }

        argbBytes.withUnsafeMutableBytes { bytes in
            var argb = vImage_Buffer(data: bytes.baseAddress,
                                     height: src.height,
                                     width:  src.width,
                                     rowBytes: argbStride)

            a8.withUnsafeMutableBufferPointer { aPtr in
                r8.withUnsafeMutableBufferPointer { rPtr in
                    g8.withUnsafeMutableBufferPointer { gPtr in
                        b8.withUnsafeMutableBufferPointer { bPtr in
                            var a = vImage_Buffer(data: aPtr.baseAddress, height: src.height, width: src.width, rowBytes: width)
                            var r = vImage_Buffer(data: rPtr.baseAddress, height: src.height, width: src.width, rowBytes: width)
                            var g = vImage_Buffer(data: gPtr.baseAddress, height: src.height, width: src.width, rowBytes: width)
                            var b = vImage_Buffer(data: bPtr.baseAddress, height: src.height, width: src.width, rowBytes: width)
                            vImageConvert_ARGB8888toPlanar8(&argb, &a, &r, &g, &b, vImage_Flags(kvImageNoFlags))
                        }
                    }
                }
            }
        }

        // (x / 255.0 - mean) / std
        
        let n = width * height
        let dst = arr.dataPointer.bindMemory(to: Float.self, capacity: 3 * n)
        
        planarR.withUnsafeMutableBytes { rPtr in
            planarG.withUnsafeMutableBytes { gPtr in
                planarB.withUnsafeMutableBytes { bPtr in
                    
                    var vR = vImage_Buffer(data: rPtr.baseAddress, height: src.height, width: src.width, rowBytes: width * 4)
                    var vG = vImage_Buffer(data: gPtr.baseAddress, height: src.height, width: src.width, rowBytes: width * 4)
                    var vB = vImage_Buffer(data: bPtr.baseAddress, height: src.height, width: src.width, rowBytes: width * 4)
                    
                    r8.withUnsafeMutableBufferPointer { r8Ptr in
                        var vR8 = vImage_Buffer(data: r8Ptr.baseAddress, height: src.height, width: src.width, rowBytes: width)
                        vImageConvert_Planar8toPlanarF(&vR8, &vR, 1.0 / std[0] / 255.0, -(mean[0] * 255.0) / (std[0] * 255.0), vImage_Flags(kvImageNoFlags))
                    }
                    g8.withUnsafeMutableBufferPointer { g8Ptr in
                        var vG8 = vImage_Buffer(data: g8Ptr.baseAddress, height: src.height, width: src.width, rowBytes: width)
                        vImageConvert_Planar8toPlanarF(&vG8, &vG, 1.0 / std[1] / 255.0, -(mean[1] * 255.0) / (std[1] * 255.0), vImage_Flags(kvImageNoFlags))
                    }
                    b8.withUnsafeMutableBufferPointer { b8Ptr in
                        var vB8 = vImage_Buffer(data: b8Ptr.baseAddress, height: src.height, width: src.width, rowBytes: width)
                        vImageConvert_Planar8toPlanarF(&vB8, &vB, 1.0 / std[2] / 255.0, -(mean[2] * 255.0) / (std[2] * 255.0), vImage_Flags(kvImageNoFlags))
                    }
                    
                    dst.update(from: rPtr.baseAddress!.assumingMemoryBound(to: Float.self), count: n)
                    (dst + n).update(from: gPtr.baseAddress!.assumingMemoryBound(to: Float.self), count: n)
                    (dst + 2*n).update(from: bPtr.baseAddress!.assumingMemoryBound(to: Float.self), count: n)
                }
            }
        }
        
        return arr
    }
}
