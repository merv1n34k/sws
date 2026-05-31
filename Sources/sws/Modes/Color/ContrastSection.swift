import AppKit

/// WCAG contrast ratio between two colors. Used inside ColorView as
/// a horizontal row.
final class ContrastSection: NSView {
    private let wellA = NSColorWell()
    private let wellB = NSColorWell()
    private let swap = NSButton(title: "⇄", target: nil, action: nil)
    private let ratioLabel = NSTextField(labelWithString: "—")
    private let verdictLabel = NSTextField(labelWithString: "")

    init() {
        super.init(frame: .zero)
        buildLayout()
        wire()

        wellA.color = .white
        wellB.color = NSColor(red: 0.09, green: 0.10, blue: 0.13, alpha: 1)
        recompute()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    private func buildLayout() {
        wellA.translatesAutoresizingMaskIntoConstraints = false
        wellB.translatesAutoresizingMaskIntoConstraints = false
        wellA.widthAnchor.constraint(equalToConstant: 32).isActive = true
        wellA.heightAnchor.constraint(equalToConstant: 22).isActive = true
        wellB.widthAnchor.constraint(equalToConstant: 32).isActive = true
        wellB.heightAnchor.constraint(equalToConstant: 22).isActive = true

        swap.bezelStyle = .inline
        swap.target = self
        swap.action = #selector(swapColors)

        ratioLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 13, weight: .medium)
        ratioLabel.textColor = .white

        verdictLabel.font = NSFont.systemFont(ofSize: 11)
        verdictLabel.textColor = .secondaryLabelColor

        let row = NSStackView(views: [
            label("Contrast"), wellA, swap, wellB, ratioLabel, verdictLabel,
        ])
        row.orientation = .horizontal
        row.spacing = 8
        row.alignment = .centerY
        row.translatesAutoresizingMaskIntoConstraints = false
        addSubview(row)
        NSLayoutConstraint.activate([
            row.topAnchor.constraint(equalTo: topAnchor),
            row.bottomAnchor.constraint(equalTo: bottomAnchor),
            row.leadingAnchor.constraint(equalTo: leadingAnchor),
            row.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor),
        ])
    }

    private func wire() {
        wellA.target = self
        wellA.action = #selector(colorChanged)
        wellB.target = self
        wellB.action = #selector(colorChanged)
    }

    @objc private func colorChanged() { recompute() }

    @objc private func swapColors() {
        let tmp = wellA.color
        wellA.color = wellB.color
        wellB.color = tmp
        recompute()
    }

    private func recompute() {
        let ratio = ContrastSection.contrastRatio(wellA.color, wellB.color)
        ratioLabel.stringValue = String(format: "%.2f : 1", ratio)
        verdictLabel.attributedStringValue = Self.verdictAttributed(ratio: ratio)
    }

    /// Color-coded verdict: green for pass, red for fail. Makes the
    /// outcome unambiguous regardless of font rendering.
    static func verdictAttributed(ratio r: Double) -> NSAttributedString {
        let entries: [(label: String, threshold: Double)] = [
            ("AA",    4.5),
            ("AA-L",  3.0),
            ("AAA",   7.0),
        ]
        let result = NSMutableAttributedString()
        for (i, e) in entries.enumerated() {
            let passes = r >= e.threshold
            let chunk = NSMutableAttributedString(
                string: "\(e.label) \(passes ? "✓" : "✗")",
                attributes: [
                    .foregroundColor: passes ? NSColor.systemGreen : NSColor.systemRed,
                    .font: NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .medium),
                ]
            )
            result.append(chunk)
            if i < entries.count - 1 {
                result.append(NSAttributedString(string: "  ", attributes: [
                    .foregroundColor: NSColor.secondaryLabelColor,
                ]))
            }
        }
        return result
    }

    /// WCAG 2.2 contrast ratio between two colors. Range [1.0, 21.0].
    static func contrastRatio(_ a: NSColor, _ b: NSColor) -> Double {
        let la = relativeLuminance(of: a)
        let lb = relativeLuminance(of: b)
        let lighter = max(la, lb)
        let darker = min(la, lb)
        return (lighter + 0.05) / (darker + 0.05)
    }

    private static func relativeLuminance(of color: NSColor) -> Double {
        let c = color.usingColorSpace(.sRGB) ?? color
        let r = channel(Double(c.redComponent))
        let g = channel(Double(c.greenComponent))
        let b = channel(Double(c.blueComponent))
        return 0.2126 * r + 0.7152 * g + 0.0722 * b
    }

    private static func channel(_ v: Double) -> Double {
        v <= 0.03928 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4)
    }

    /// Returns the WCAG verdict string, e.g. "AA ✓ · AAA ✓".
    static func verdict(ratio r: Double) -> String {
        let aaSmall  = r >= 4.5  ? "AA ✓"   : "AA ✗"
        let aaLarge  = r >= 3.0  ? "AA-L ✓" : "AA-L ✗"
        let aaaSmall = r >= 7.0  ? "AAA ✓"  : "AAA ✗"
        return [aaSmall, aaLarge, aaaSmall].joined(separator: " · ")
    }

    private func label(_ s: String) -> NSTextField {
        let l = NSTextField(labelWithString: s)
        l.textColor = .secondaryLabelColor
        l.font = NSFont.systemFont(ofSize: 11, weight: .medium)
        return l
    }
}
