import Foundation
import AppKit

struct URLCodec: EnDeCodec {
    let displayName = "URL"
    let bidirectional = true
    let rightIsImage = false

    func transformLeftToRight(_ left: String) -> String {
        // queryAllowed is the strictest commonly-useful set; matches
        // what most "URL encode" tools produce.
        left.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
    }

    func transformRightToLeft(_ right: String) -> String {
        right.removingPercentEncoding ?? ""
    }
}
