import CoreGraphics
import Foundation
import Vision

public enum OCRService {
    public static func recognize(_ image: CGImage, keepLineBreaks: Bool) throws -> String {
        let preferred = Array(Locale.preferredLanguages.prefix(4))
        let request = makeRequest(languages: preferred)
        do {
            try VNImageRequestHandler(cgImage: image, options: [:]).perform([request])
            return assemble(request, keepLineBreaks: keepLineBreaks)
        } catch {
            let fallback = makeRequest(languages: ["en-US"])
            try VNImageRequestHandler(cgImage: image, options: [:]).perform([fallback])
            return assemble(fallback, keepLineBreaks: keepLineBreaks)
        }
    }

    private static func makeRequest(languages: [String]) -> VNRecognizeTextRequest {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.automaticallyDetectsLanguage = true
        request.minimumTextHeight = 0
        if !languages.isEmpty {
            request.recognitionLanguages = languages
        }
        return request
    }

    private static func assemble(_ request: VNRecognizeTextRequest, keepLineBreaks: Bool) -> String {
        let pieces = (request.results ?? []).compactMap { observation -> TextPiece? in
            guard let text = observation.topCandidates(1).first?.string else { return nil }
            return TextPiece(text: text, box: observation.boundingBox)
        }
        return TextAssembly.assemble(pieces, keepLineBreaks: keepLineBreaks)
    }
}
