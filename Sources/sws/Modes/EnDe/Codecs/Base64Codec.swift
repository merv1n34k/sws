import Foundation
import AppKit

struct Base64Codec: EnDeCodec {
    let displayName = "Base64"
    let hint = "Edit either side — text on the left, base64 on the right (bidirectional)."
    let samplePlaceholder = "Hello, sws!"
    let bidirectional = true
    let rightIsImage = false

    func transformLeftToRight(_ left: String) -> String {
        guard let data = left.data(using: .utf8) else { return "" }
        return data.base64EncodedString()
    }

    func transformRightToLeft(_ right: String) -> String {
        // Tolerate whitespace inside pasted base64.
        let cleaned = right.filter { !$0.isWhitespace }
        guard let data = Data(base64Encoded: cleaned),
              let text = String(data: data, encoding: .utf8) else {
            return ""
        }
        return text
    }
}
