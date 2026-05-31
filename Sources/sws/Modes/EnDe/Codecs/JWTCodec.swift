import Foundation
import AppKit

/// JWT decoder. Left = encoded JWT (xxx.yyy.zzz), right = pretty
/// printed header + payload JSON. One-way only (we don't sign).
struct JWTCodec: EnDeCodec {
    let displayName = "JWT"
    let hint = "Paste a JWT (xxx.yyy.zzz) on the left → decoded header + payload on the right."
    let samplePlaceholder = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0IiwibmFtZSI6IkphbmUifQ.signature"
    let bidirectional = false
    let rightIsImage = false

    func transformLeftToRight(_ left: String) -> String {
        let token = left.trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = token.split(separator: ".").map(String.init)
        guard parts.count >= 2 else { return "(JWT needs 3 dot-separated parts)" }

        let header = decodePart(parts[0])
        let payload = decodePart(parts[1])
        var out = "// HEADER\n"
        out += header ?? "(invalid header)"
        out += "\n\n// PAYLOAD\n"
        out += payload ?? "(invalid payload)"
        if parts.count >= 3 {
            out += "\n\n// SIGNATURE (\(parts[2].count) chars, not verified)"
        }
        return out
    }

    func transformRightToLeft(_ right: String) -> String { "" }

    private func decodePart(_ part: String) -> String? {
        // JWT uses base64url (no padding, '-' '_' instead of '+' '/').
        var s = part.replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let padding = (4 - (s.count % 4)) % 4
        s += String(repeating: "=", count: padding)
        guard let data = Data(base64Encoded: s),
              let obj = try? JSONSerialization.jsonObject(with: data),
              let pretty = try? JSONSerialization.data(
                withJSONObject: obj,
                options: [.prettyPrinted, .sortedKeys]
              ),
              let str = String(data: pretty, encoding: .utf8) else {
            return nil
        }
        return str
    }
}
