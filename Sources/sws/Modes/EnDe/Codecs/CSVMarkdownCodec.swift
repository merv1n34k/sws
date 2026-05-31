import Foundation
import AppKit

/// CSV ↔ Markdown table. Left = CSV (comma- or tab-separated).
/// Right = pipe-delimited Markdown table.
struct CSVMarkdownCodec: EnDeCodec {
    let displayName = "CSV ↔ Markdown"
    let hint = "Comma- or tab-separated CSV on the left, Markdown table on the right."
    let samplePlaceholder = "name,age,city\nAlice,30,Berlin\nBob,25,Paris"
    let bidirectional = true
    let rightIsImage = false

    func transformLeftToRight(_ left: String) -> String {
        let rows = parseCSV(left)
        guard !rows.isEmpty else { return "" }
        return CSVMarkdownCodec.emitMarkdown(rows: rows)
    }

    func transformRightToLeft(_ right: String) -> String {
        let rows = parseMarkdown(right)
        guard !rows.isEmpty else { return "" }
        return CSVMarkdownCodec.emitCSV(rows: rows)
    }

    // MARK: - CSV parser (simple — handles comma/tab, quoted fields)

    private func parseCSV(_ s: String) -> [[String]] {
        let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        // Pick delimiter from the first line — comma wins unless the
        // first line has more tabs than commas.
        let firstLine = trimmed.split(whereSeparator: \.isNewline).first.map(String.init) ?? trimmed
        let delim: Character = firstLine.filter { $0 == "\t" }.count > firstLine.filter { $0 == "," }.count ? "\t" : ","

        var rows: [[String]] = []
        for line in trimmed.split(whereSeparator: \.isNewline) {
            rows.append(splitCSVLine(String(line), delim: delim))
        }
        return rows
    }

    private func splitCSVLine(_ line: String, delim: Character) -> [String] {
        var fields: [String] = []
        var current = ""
        var inQuotes = false
        for ch in line {
            if ch == "\"" {
                inQuotes.toggle()
                continue
            }
            if ch == delim && !inQuotes {
                fields.append(current)
                current = ""
            } else {
                current.append(ch)
            }
        }
        fields.append(current)
        return fields.map { $0.trimmingCharacters(in: .whitespaces) }
    }

    // MARK: - Markdown parser

    private func parseMarkdown(_ s: String) -> [[String]] {
        let lines = s.split(whereSeparator: \.isNewline)
            .map { String($0).trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        guard !lines.isEmpty else { return [] }
        var rows: [[String]] = []
        for line in lines {
            // Skip the separator row (e.g. |---|---|).
            let stripped = line.trimmingCharacters(in: CharacterSet(charactersIn: "| "))
            if stripped.allSatisfy({ "-:|".contains($0) || $0.isWhitespace }) { continue }
            // Split on pipes, drop leading/trailing empty fields produced by
            // outer pipes "| a | b |" → ["", " a ", " b ", ""].
            var fields = line.split(separator: "|", omittingEmptySubsequences: false).map(String.init)
            if fields.first?.trimmingCharacters(in: .whitespaces).isEmpty == true { fields.removeFirst() }
            if fields.last?.trimmingCharacters(in: .whitespaces).isEmpty == true { fields.removeLast() }
            rows.append(fields.map { $0.trimmingCharacters(in: .whitespaces) })
        }
        return rows
    }

    // MARK: - Emit

    static func emitMarkdown(rows: [[String]]) -> String {
        // Pad rows to uniform column count.
        let cols = rows.map(\.count).max() ?? 0
        let padded = rows.map { $0 + Array(repeating: "", count: max(0, cols - $0.count)) }
        // Column widths for pretty alignment.
        var widths = Array(repeating: 0, count: cols)
        for row in padded {
            for (i, cell) in row.enumerated() {
                widths[i] = max(widths[i], cell.count)
            }
        }
        func format(_ row: [String]) -> String {
            "| " + row.enumerated().map { i, c in
                c.padding(toLength: widths[i], withPad: " ", startingAt: 0)
            }.joined(separator: " | ") + " |"
        }
        var lines: [String] = []
        if let header = padded.first { lines.append(format(header)) }
        let sep = "|" + widths.map { String(repeating: "-", count: $0 + 2) }.joined(separator: "|") + "|"
        lines.append(sep)
        for row in padded.dropFirst() { lines.append(format(row)) }
        return lines.joined(separator: "\n")
    }

    static func emitCSV(rows: [[String]]) -> String {
        rows.map { row in
            row.map { field in
                // Quote if the field contains a comma, quote, or newline.
                if field.contains(",") || field.contains("\"") || field.contains("\n") {
                    let escaped = field.replacingOccurrences(of: "\"", with: "\"\"")
                    return "\"\(escaped)\""
                }
                return field
            }.joined(separator: ",")
        }.joined(separator: "\n")
    }
}
