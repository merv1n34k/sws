import Testing
import Foundation
@testable import sws

@Suite("Generators")
struct GeneratorsTests {
    @Test
    func passwordRespectsLengthAndCharset() {
        var opts = Generators.PasswordOptions()
        opts.length = 32
        opts.symbols = false
        let p = Generators.password(options: opts)
        #expect(p.count == 32)
        let allowed = Set("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789")
        for ch in p {
            #expect(allowed.contains(ch))
        }
    }

    @Test
    func passwordWithNoClassesIsEmpty() {
        var opts = Generators.PasswordOptions()
        opts.lowercase = false; opts.uppercase = false
        opts.digits = false; opts.symbols = false
        #expect(Generators.password(options: opts).isEmpty)
    }

    @Test
    func uuidV4Format() {
        let ids = Generators.generateIDs(kind: .v4, count: 10)
        let v4Regex = #/^[0-9A-F]{8}-[0-9A-F]{4}-4[0-9A-F]{3}-[89AB][0-9A-F]{3}-[0-9A-F]{12}$/#
        for s in ids {
            #expect(s.wholeMatch(of: v4Regex) != nil, "not a v4 UUID: \(s)")
        }
    }

    @Test
    func uuidV7Format() {
        let ids = Generators.generateIDs(kind: .v7, count: 5)
        let v7Regex = #/^[0-9A-F]{8}-[0-9A-F]{4}-7[0-9A-F]{3}-[89AB][0-9A-F]{3}-[0-9A-F]{12}$/#
        for s in ids {
            #expect(s.wholeMatch(of: v7Regex) != nil, "not a v7 UUID: \(s)")
        }
    }

    @Test
    func ulidFormat() {
        let ids = Generators.generateIDs(kind: .ulid, count: 5)
        let ulidRegex = #/^[0-9A-HJKMNP-TV-Z]{26}$/#
        for s in ids {
            #expect(s.wholeMatch(of: ulidRegex) != nil, "not a ULID: \(s)")
        }
    }

    @Test
    func loremWordCount() {
        let s = Generators.lorem(unit: .words, count: 20)
        let parts = s.split(separator: " ")
        #expect(parts.count == 20)
    }

    @Test
    func loremSentencesEndWithPeriod() {
        let s = Generators.lorem(unit: .sentences, count: 3)
        let sentences = s.components(separatedBy: ". ").filter { !$0.isEmpty }
        #expect(sentences.count >= 1)
        #expect(s.hasSuffix("."))
    }

    @Test
    func randomPickerWithoutReplacementExhausts() {
        let items = ["a", "b", "c"]
        var picked: Set<String> = []
        for _ in 0..<3 {
            if let p = Generators.pickRandom(from: items, withoutReplacement: true, alreadyPicked: picked) {
                picked.insert(p)
            }
        }
        #expect(picked.count == 3)
        let next = Generators.pickRandom(from: items, withoutReplacement: true, alreadyPicked: picked)
        #expect(next == nil)
    }
}
