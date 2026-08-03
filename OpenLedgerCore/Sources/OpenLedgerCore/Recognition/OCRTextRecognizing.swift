import CoreGraphics
import Foundation
import Vision

public protocol OCRTextRecognizing: Sendable {
    func recognizeText(in image: CGImage) throws -> [String]
}

/// 基于 Apple Vision 的本机 OCR，支持简体中文。
public struct VisionTextRecognizer: OCRTextRecognizing {
    public init() {}

    public func recognizeText(in image: CGImage) throws -> [String] {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.recognitionLanguages = ["zh-Hans", "en-US"]

        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        try handler.perform([request])

        return (request.results ?? []).compactMap { $0.topCandidates(1).first?.string }
    }
}
