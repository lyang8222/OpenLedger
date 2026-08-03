import CoreGraphics
import Foundation

/// OCR + 模板解析的组合入口。
public struct RecognitionPipeline: Sendable {
    private let recognizer: any OCRTextRecognizing
    private let parser: PaymentTemplateParser

    public init(
        recognizer: any OCRTextRecognizing = VisionTextRecognizer(),
        parser: PaymentTemplateParser = PaymentTemplateParser()
    ) {
        self.recognizer = recognizer
        self.parser = parser
    }

    public func recognize(cgImage: CGImage) throws -> PaymentDraft {
        let lines = try recognizer.recognizeText(in: cgImage)
        return parser.parse(lines: lines)
    }
}
