import AppKit
import CoreImage
import Vision

/// Linear barcode codec — generator uses Code 128 (works for most
/// ASCII text). Reader accepts any 1D symbology Vision supports.
struct BarcodeCodec: EnDeCodec {
    let displayName = "Barcode"
    let hint = "Type on the left → Code 128 barcode on the right. Click to copy. Drop a barcode image to decode."
    let samplePlaceholder = "12345-ABCDE"
    let bidirectional = false
    let rightIsImage = true

    func transformLeftToRight(_ left: String) -> String { "" }
    func transformRightToLeft(_ right: String) -> String { "" }

    func imageFor(leftText: String) -> NSImage? {
        let text = leftText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty,
              let data = text.data(using: .ascii) else { return nil }
        guard let filter = CIFilter(name: "CICode128BarcodeGenerator") else { return nil }
        filter.setValue(data, forKey: "inputMessage")
        filter.setValue(10, forKey: "inputQuietSpace")
        guard let output = filter.outputImage else { return nil }
        let scale: CGFloat = 3
        let scaled = output.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        let rep = NSCIImageRep(ciImage: scaled)
        let img = NSImage(size: rep.size)
        img.addRepresentation(rep)
        return img
    }

    func textFrom(image: NSImage) -> String? {
        guard let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }
        let request = VNDetectBarcodesRequest()
        // Common linear barcodes; .qr is excluded here on purpose to
        // keep this codec text-only — use the QR codec for QR images.
        request.symbologies = [
            .code128, .code39, .code93,
            .ean8, .ean13,
            .upce,
            .itf14,
            .pdf417,
        ]
        let handler = VNImageRequestHandler(cgImage: cg)
        try? handler.perform([request])
        guard let observations = request.results else { return nil }
        return observations.compactMap { $0.payloadStringValue }.first
    }
}
