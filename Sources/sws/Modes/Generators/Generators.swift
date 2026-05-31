import Foundation

/// Pure-logic generators. No state, no I/O — easy to unit-test.
enum Generators {

    // MARK: - Password

    struct PasswordOptions {
        var length: Int = 20
        var lowercase: Bool = true
        var uppercase: Bool = true
        var digits: Bool = true
        var symbols: Bool = true

        var charset: String {
            var s = ""
            if lowercase { s += "abcdefghijklmnopqrstuvwxyz" }
            if uppercase { s += "ABCDEFGHIJKLMNOPQRSTUVWXYZ" }
            if digits    { s += "0123456789" }
            if symbols   { s += "!@#$%^&*()-_=+[]{}<>?,.;:/~" }
            return s
        }
    }

    /// Generates a password of `length` from the configured charset.
    /// Returns empty string if every class is disabled.
    static func password(options: PasswordOptions) -> String {
        let chars = Array(options.charset)
        guard !chars.isEmpty, options.length > 0 else { return "" }
        var out = ""
        out.reserveCapacity(options.length)
        for _ in 0..<options.length {
            let idx = Int.random(in: 0..<chars.count)
            out.append(chars[idx])
        }
        return out
    }

    // MARK: - UUID / ULID

    enum IDKind: String, CaseIterable {
        case v4 = "v4"
        case v7 = "v7"
        case ulid = "ULID"
    }

    static func generateIDs(kind: IDKind, count: Int) -> [String] {
        (0..<max(0, count)).map { _ in generateID(kind: kind) }
    }

    static func generateID(kind: IDKind) -> String {
        switch kind {
        case .v4:   return UUID().uuidString
        case .v7:   return uuidV7().uuidString
        case .ulid: return ulid()
        }
    }

    /// RFC 9562 UUID v7: 48-bit ms timestamp + version(4) + 12 random + variant(2) + 62 random.
    static func uuidV7(now: Date = Date(), random: () -> UInt64 = { UInt64.random(in: 0...UInt64.max) }) -> UUID {
        let ms = UInt64(now.timeIntervalSince1970 * 1000) & 0x0000_FFFF_FFFF_FFFF
        let r1 = random()
        let r2 = random()
        var bytes = [UInt8](repeating: 0, count: 16)
        // 48-bit timestamp (big-endian) in bytes[0..6]
        bytes[0] = UInt8((ms >> 40) & 0xFF)
        bytes[1] = UInt8((ms >> 32) & 0xFF)
        bytes[2] = UInt8((ms >> 24) & 0xFF)
        bytes[3] = UInt8((ms >> 16) & 0xFF)
        bytes[4] = UInt8((ms >>  8) & 0xFF)
        bytes[5] = UInt8(ms & 0xFF)
        // version 7 in high nibble of byte 6
        bytes[6] = 0x70 | UInt8((r1 >> 8) & 0x0F)
        bytes[7] = UInt8(r1 & 0xFF)
        // variant 10 in top two bits of byte 8
        bytes[8] = 0x80 | UInt8((r1 >> 16) & 0x3F)
        bytes[9] = UInt8((r1 >> 24) & 0xFF)
        bytes[10] = UInt8((r2 >>  0) & 0xFF)
        bytes[11] = UInt8((r2 >>  8) & 0xFF)
        bytes[12] = UInt8((r2 >> 16) & 0xFF)
        bytes[13] = UInt8((r2 >> 24) & 0xFF)
        bytes[14] = UInt8((r2 >> 32) & 0xFF)
        bytes[15] = UInt8((r2 >> 40) & 0xFF)
        return UUID(uuid: (
            bytes[0], bytes[1], bytes[2], bytes[3],
            bytes[4], bytes[5], bytes[6], bytes[7],
            bytes[8], bytes[9], bytes[10], bytes[11],
            bytes[12], bytes[13], bytes[14], bytes[15]
        ))
    }

    /// ULID: Crockford base-32, 48-bit ms timestamp + 80-bit random.
    static func ulid(now: Date = Date(), random: () -> UInt64 = { UInt64.random(in: 0...UInt64.max) }) -> String {
        let alphabet = Array("0123456789ABCDEFGHJKMNPQRSTVWXYZ")
        let ms = UInt64(now.timeIntervalSince1970 * 1000)
        var out = ""
        // 10 chars from 48-bit timestamp (5 bits per char)
        for i in (0..<10).reversed() {
            let shift = i * 5
            let idx = Int((ms >> shift) & 0x1F)
            out.append(alphabet[idx])
        }
        // 16 chars from 80 bits of randomness
        let r1 = random()
        let r2 = random()
        for i in (0..<8).reversed() {
            let idx = Int((r1 >> (i * 5)) & 0x1F)
            out.append(alphabet[idx])
        }
        for i in (0..<8).reversed() {
            let idx = Int((r2 >> (i * 5)) & 0x1F)
            out.append(alphabet[idx])
        }
        return out
    }

    // MARK: - Lorem ipsum

    enum LoremUnit: String, CaseIterable {
        case words, sentences, paragraphs
    }

    private static let loremWords = [
        "lorem","ipsum","dolor","sit","amet","consectetur","adipiscing","elit",
        "sed","do","eiusmod","tempor","incididunt","ut","labore","et","dolore",
        "magna","aliqua","enim","ad","minim","veniam","quis","nostrud",
        "exercitation","ullamco","laboris","nisi","aliquip","ex","ea","commodo",
        "consequat","duis","aute","irure","in","reprehenderit","voluptate",
        "velit","esse","cillum","fugiat","nulla","pariatur","excepteur","sint",
        "occaecat","cupidatat","non","proident","sunt","culpa","qui","officia",
        "deserunt","mollit","anim","id","est","laborum"
    ]

    static func lorem(unit: LoremUnit, count: Int) -> String {
        let n = max(0, count)
        switch unit {
        case .words:
            return (0..<n).map { _ in loremWords.randomElement()! }.joined(separator: " ")
        case .sentences:
            return (0..<n).map { _ in loremSentence() }.joined(separator: " ")
        case .paragraphs:
            return (0..<n).map { _ in loremParagraph() }.joined(separator: "\n\n")
        }
    }

    private static func loremSentence() -> String {
        let length = Int.random(in: 6...14)
        var words = (0..<length).map { _ in loremWords.randomElement()! }
        words[0] = words[0].prefix(1).uppercased() + words[0].dropFirst()
        return words.joined(separator: " ") + "."
    }

    private static func loremParagraph() -> String {
        let sentences = Int.random(in: 3...6)
        return (0..<sentences).map { _ in loremSentence() }.joined(separator: " ")
    }

    // MARK: - Random picker

    static func pickRandom(from items: [String], withoutReplacement: Bool, alreadyPicked: Set<String>) -> String? {
        let pool = withoutReplacement
            ? items.filter { !alreadyPicked.contains($0) }
            : items
        return pool.randomElement()
    }
}
