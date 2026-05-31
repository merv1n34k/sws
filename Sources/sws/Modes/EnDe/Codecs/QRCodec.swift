import AppKit
import CoreImage
import Vision

struct QRCodec: EnDeCodec {
    let displayName = "QR"
    let bidirectional = false
    let rightIsImage = true

    func transformLeftToRight(_ left: String) -> String { "" }
    func transformRightToLeft(_ right: String) -> String { "" }

    func imageFor(leftText: String) -> NSImage? {
        let text = leftText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty,
              let data = text.data(using: .utf8) else { return nil }
        guard let filter = CIFilter(name: "CIQRCodeGenerator") else { return nil }
        filter.setValue(data, forKey: "inputMessage")
        filter.setValue("M", forKey: "inputCorrectionLevel")
        guard let output = filter.outputImage else { return nil }
        // Scale up so it's not tiny — CIQRCodeGenerator emits 1 pt per module.
        let scale: CGFloat = 8
        let scaled = output.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        let rep = NSCIImageRep(ciImage: scaled)
        let img = NSImage(size: rep.size)
        img.addRepresentation(rep)
        return img
    }

    func textFrom(image: NSImage) -> String? {
        guard let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }
        let request = VNDetectBarcodesRequest()
        request.symbologies = [.qr]
        let handler = VNImageRequestHandler(cgImage: cg)
        try? handler.perform([request])
        guard let observations = request.results else { return nil }
        return observations.compactMap { $0.payloadStringValue }.first
    }
}
