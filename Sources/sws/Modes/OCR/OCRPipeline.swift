import Foundation
import AppKit
import Vision
import PDFKit

/// Recognizes text from images or PDFs via Apple's Vision framework.
/// All work happens on a background queue; completion fires on main.
enum OCRPipeline {

    enum Source {
        case image(NSImage)
        case pdf(URL)
        case cgImage(CGImage)
    }

    /// Recognized-text-per-page for PDFs; single entry for images.
    struct Result {
        let pages: [String]
        var joined: String {
            pages.enumerated().map { i, p in
                pages.count > 1 ? "=== page \(i + 1) ===\n\(p)" : p
            }.joined(separator: "\n\n")
        }
    }

    static func recognize(
        source: Source,
        language: String? = nil,
        completion: @escaping (Result?) -> Void
    ) {
        DispatchQueue.global(qos: .userInitiated).async {
            let result: Result?
            switch source {
            case .image(let img):
                if let cg = img.cgImage(forProposedRect: nil, context: nil, hints: nil) {
                    result = Result(pages: [textFrom(cgImage: cg, language: language)])
                } else {
                    result = nil
                }
            case .cgImage(let cg):
                result = Result(pages: [textFrom(cgImage: cg, language: language)])
            case .pdf(let url):
                result = textFrom(pdfURL: url, language: language)
            }
            DispatchQueue.main.async { completion(result) }
        }
    }

    private static func textFrom(cgImage: CGImage, language: String?) -> String {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        if let lang = language { request.recognitionLanguages = [lang] }
        request.usesLanguageCorrection = true
        let handler = VNImageRequestHandler(cgImage: cgImage)
        do {
            try handler.perform([request])
        } catch {
            return "(OCR failed: \(error.localizedDescription))"
        }
        guard let observations = request.results else { return "" }
        return observations
            .compactMap { $0.topCandidates(1).first?.string }
            .joined(separator: "\n")
    }

    private static func textFrom(pdfURL: URL, language: String?) -> Result? {
        guard let doc = PDFDocument(url: pdfURL) else { return nil }
        var pages: [String] = []
        for i in 0..<doc.pageCount {
            guard let page = doc.page(at: i) else { continue }
            let bounds = page.bounds(for: .mediaBox)
            let scale: CGFloat = 2
            let size = NSSize(width: bounds.width * scale, height: bounds.height * scale)
            let image = NSImage(size: size)
            image.lockFocus()
            if let ctx = NSGraphicsContext.current {
                ctx.cgContext.setFillColor(NSColor.white.cgColor)
                ctx.cgContext.fill(CGRect(origin: .zero, size: size))
                ctx.cgContext.scaleBy(x: scale, y: scale)
                page.draw(with: .mediaBox, to: ctx.cgContext)
            }
            image.unlockFocus()
            if let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil) {
                pages.append(textFrom(cgImage: cg, language: language))
            }
        }
        return Result(pages: pages)
    }

    /// macOS Vision recognition languages, e.g. en-US, ru-RU, ja-JP.
    static var supportedLanguages: [String] {
        // VNRecognizeTextRequest.supportedRecognitionLanguages requires
        // a request object. Construct a throwaway one to query.
        let req = VNRecognizeTextRequest()
        return (try? req.supportedRecognitionLanguages()) ?? ["en-US"]
    }
}
