import Testing
import Foundation
@testable import sws

@Suite("Codecs")
struct CodecsTests {
    @Test
    func base64RoundTrip() {
        let codec = Base64Codec()
        let original = "Hello, sws! Δ"
        let encoded = codec.transformLeftToRight(original)
        let decoded = codec.transformRightToLeft(encoded)
        #expect(decoded == original)
    }

    @Test
    func urlEncodeRoundTrip() {
        let codec = URLCodec()
        let original = "key=hello world&v=я"
        let encoded = codec.transformLeftToRight(original)
        let decoded = codec.transformRightToLeft(encoded)
        #expect(decoded == original)
    }

    @Test
    func csvToMarkdown() {
        let codec = CSVMarkdownCodec()
        let csv = "name,age\nAlice,30\nBob,25"
        let md = codec.transformLeftToRight(csv)
        #expect(md.contains("| name"))
        #expect(md.contains("| Alice"))
        #expect(md.contains("| Bob"))
        #expect(md.contains("|---"))
    }

    @Test
    func markdownToCSV() {
        let codec = CSVMarkdownCodec()
        let md = """
        | name | age |
        |------|-----|
        | Alice | 30 |
        | Bob   | 25 |
        """
        let csv = codec.transformRightToLeft(md)
        let lines = csv.split(separator: "\n").map(String.init)
        #expect(lines.first == "name,age")
        #expect(lines.contains("Alice,30"))
        #expect(lines.contains("Bob,25"))
    }

    @Test
    func jwtDecodesKnownFixture() {
        // {"alg":"HS256","typ":"JWT"} . {"sub":"1234","name":"Jane"} . sig
        let codec = JWTCodec()
        let jwt = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0IiwibmFtZSI6IkphbmUifQ.signature"
        let out = codec.transformLeftToRight(jwt)
        #expect(out.contains("\"alg\""))
        #expect(out.contains("HS256"))
        #expect(out.contains("\"name\""))
        #expect(out.contains("Jane"))
    }

    @Test
    func jwtMalformedReportsError() {
        let codec = JWTCodec()
        let out = codec.transformLeftToRight("notajwt")
        #expect(out.contains("3 dot-separated parts"))
    }
}
