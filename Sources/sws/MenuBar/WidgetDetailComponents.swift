import AppKit

// MARK: - Sparkline

/// Compact inline line chart. Append samples with `add(_:)`; the view
/// keeps a ring buffer and redraws. Y axis is auto-scaled to the
/// observed min/max with a small headroom.
final class Sparkline: NSView {
    private var samples: [Double] = []
    var capacity: Int = 60
    /// Optional manual y-axis range. If nil, samples drive the scale.
    var yRange: ClosedRange<Double>? = nil
    var lineColor: NSColor = .systemBlue
    var fillColor: NSColor = NSColor.systemBlue.withAlphaComponent(0.18)
    var gridColor: NSColor = NSColor.separatorColor.withAlphaComponent(0.35)

    init() {
        super.init(frame: NSRect(x: 0, y: 0, width: 240, height: 60))
        wantsLayer = true
        layer?.backgroundColor = NSColor(white: 0.0, alpha: 0.08).cgColor
        layer?.cornerRadius = 6
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    func add(_ value: Double) {
        samples.append(value)
        if samples.count > capacity {
            samples.removeFirst(samples.count - capacity)
        }
        needsDisplay = true
    }

    func reset() {
        samples.removeAll()
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        let r = bounds.insetBy(dx: 4, dy: 4)
        guard r.width > 0, r.height > 0, !samples.isEmpty else {
            drawEmpty(in: r)
            return
        }

        let (lo, hi) = scaleBounds()
        let span = max(1e-6, hi - lo)

        // Subtle horizontal grid: 25%, 50%, 75%.
        gridColor.setStroke()
        let grid = NSBezierPath()
        grid.lineWidth = 0.5
        for frac in [0.25, 0.5, 0.75] {
            let y = r.minY + r.height * CGFloat(1.0 - frac)
            grid.move(to: NSPoint(x: r.minX, y: y))
            grid.line(to: NSPoint(x: r.maxX, y: y))
        }
        grid.stroke()

        // Line + fill.
        let step = samples.count > 1 ? r.width / CGFloat(samples.count - 1) : r.width
        let path = NSBezierPath()
        let fill = NSBezierPath()
        fill.move(to: NSPoint(x: r.minX, y: r.minY))
        for (i, v) in samples.enumerated() {
            let x = r.minX + CGFloat(i) * step
            let y = r.minY + r.height * CGFloat((v - lo) / span)
            let p = NSPoint(x: x, y: y)
            if i == 0 {
                path.move(to: p)
                fill.line(to: p)
            } else {
                path.line(to: p)
                fill.line(to: p)
            }
        }
        fill.line(to: NSPoint(x: r.minX + CGFloat(samples.count - 1) * step, y: r.minY))
        fill.close()

        fillColor.setFill()
        fill.fill()
        lineColor.setStroke()
        path.lineWidth = 1.5
        path.stroke()
    }

    private func drawEmpty(in r: NSRect) {
        let p = NSBezierPath()
        p.lineWidth = 0.5
        gridColor.setStroke()
        let mid = r.midY
        p.move(to: NSPoint(x: r.minX, y: mid))
        p.line(to: NSPoint(x: r.maxX, y: mid))
        p.stroke()
    }

    private func scaleBounds() -> (Double, Double) {
        if let range = yRange { return (range.lowerBound, range.upperBound) }
        guard let lo = samples.min(), let hi = samples.max() else { return (0, 1) }
        if hi == lo { return (lo - 1, hi + 1) }
        let pad = (hi - lo) * 0.1
        return (max(0, lo - pad), hi + pad)
    }
}

// MARK: - Stacked sparkline

/// Two-series stacked area chart used by CPU (user + system) and
/// anywhere else we want to break a 0–1 fraction into components.
/// Bottom series renders first (`primary`), then the second sits on
/// top of it (`secondary`).
final class StackedSparkline: NSView {
    struct Point {
        var primary: Double
        var secondary: Double
    }

    private var samples: [Point] = []
    var capacity: Int = 60
    /// y-axis ceiling. Sum is clamped at this.
    var yMax: Double = 1.0
    var primaryColor: NSColor = .systemBlue
    var secondaryColor: NSColor = .systemRed
    var gridColor: NSColor = NSColor.separatorColor.withAlphaComponent(0.35)

    init() {
        super.init(frame: NSRect(x: 0, y: 0, width: 240, height: 60))
        wantsLayer = true
        layer?.backgroundColor = NSColor(white: 0.0, alpha: 0.08).cgColor
        layer?.cornerRadius = 6
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    func add(_ point: Point) {
        samples.append(point)
        if samples.count > capacity {
            samples.removeFirst(samples.count - capacity)
        }
        needsDisplay = true
    }

    func reset() {
        samples.removeAll()
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        let r = bounds.insetBy(dx: 4, dy: 4)
        guard r.width > 0, r.height > 0 else { return }

        gridColor.setStroke()
        let grid = NSBezierPath()
        grid.lineWidth = 0.5
        for frac in [0.25, 0.5, 0.75] {
            let y = r.minY + r.height * CGFloat(1.0 - frac)
            grid.move(to: NSPoint(x: r.minX, y: y))
            grid.line(to: NSPoint(x: r.maxX, y: y))
        }
        grid.stroke()

        guard !samples.isEmpty else { return }
        let step = samples.count > 1 ? r.width / CGFloat(samples.count - 1) : r.width

        func yFor(_ value: Double) -> CGFloat {
            r.minY + r.height * CGFloat(min(value, yMax) / yMax)
        }

        let primaryFill = NSBezierPath()
        let primaryLine = NSBezierPath()
        let secondaryFill = NSBezierPath()
        let secondaryLine = NSBezierPath()

        primaryFill.move(to: NSPoint(x: r.minX, y: r.minY))
        secondaryFill.move(to: NSPoint(x: r.minX, y: r.minY))

        for (i, p) in samples.enumerated() {
            let x = r.minX + CGFloat(i) * step
            let yP = yFor(p.primary)
            let yS = yFor(p.primary + p.secondary)
            let pPoint = NSPoint(x: x, y: yP)
            let sPoint = NSPoint(x: x, y: yS)
            if i == 0 {
                primaryLine.move(to: pPoint)
                secondaryLine.move(to: sPoint)
                primaryFill.line(to: pPoint)
                secondaryFill.line(to: sPoint)
            } else {
                primaryLine.line(to: pPoint)
                secondaryLine.line(to: sPoint)
                primaryFill.line(to: pPoint)
                secondaryFill.line(to: sPoint)
            }
        }
        let last = samples.count - 1
        let lastX = r.minX + CGFloat(last) * step
        primaryFill.line(to: NSPoint(x: lastX, y: r.minY))
        primaryFill.close()
        secondaryFill.line(to: NSPoint(x: lastX, y: r.minY))
        secondaryFill.close()

        // Bottom layer first.
        primaryColor.withAlphaComponent(0.30).setFill()
        primaryFill.fill()
        secondaryColor.withAlphaComponent(0.30).setFill()
        // Draw secondary as the area above primary. Re-build a polygon
        // for [primary line ... secondary line back] so the fill sits
        // on top of the primary band instead of from x-axis.
        let band = NSBezierPath()
        for (i, p) in samples.enumerated() {
            let x = r.minX + CGFloat(i) * step
            let y = yFor(p.primary)
            if i == 0 { band.move(to: NSPoint(x: x, y: y)) }
            else { band.line(to: NSPoint(x: x, y: y)) }
        }
        for (i, p) in samples.enumerated().reversed() {
            let x = r.minX + CGFloat(i) * step
            let y = yFor(p.primary + p.secondary)
            band.line(to: NSPoint(x: x, y: y))
        }
        band.close()
        band.fill()

        primaryColor.setStroke()
        primaryLine.lineWidth = 1.2
        primaryLine.stroke()
        secondaryColor.setStroke()
        secondaryLine.lineWidth = 1.2
        secondaryLine.stroke()
    }
}

// MARK: - Capacity bar

/// Native fill bar for storage / quota readouts. Wraps NSLevelIndicator
/// in its continuous-capacity style, which is what macOS uses in
/// "About this Mac → Storage" and the Preferences disk row.
final class CapacityBar: NSView {
    private let indicator: NSLevelIndicator

    /// `fill` is 0...1. Setting it also recomputes the warning/critical
    /// thresholds so the NSLevelIndicator switches between green /
    /// yellow / red segments based on the current value.
    var fill: Double = 0 {
        didSet {
            indicator.doubleValue = max(0, min(1, fill))
        }
    }

    /// Thresholds at which the bar tint shifts to yellow then red.
    /// `(yellowAt, redAt)` — values are 0...1.
    var thresholds: (yellow: Double, red: Double) = (0.85, 0.95) {
        didSet {
            indicator.warningValue = thresholds.yellow
            indicator.criticalValue = thresholds.red
        }
    }

    init() {
        self.indicator = NSLevelIndicator(frame: .zero)
        super.init(frame: .zero)
        indicator.levelIndicatorStyle = .continuousCapacity
        indicator.minValue = 0
        indicator.maxValue = 1
        indicator.warningValue = thresholds.yellow
        indicator.criticalValue = thresholds.red
        indicator.translatesAutoresizingMaskIntoConstraints = false
        addSubview(indicator)
        NSLayoutConstraint.activate([
            indicator.topAnchor.constraint(equalTo: topAnchor),
            indicator.bottomAnchor.constraint(equalTo: bottomAnchor),
            indicator.leadingAnchor.constraint(equalTo: leadingAnchor),
            indicator.trailingAnchor.constraint(equalTo: trailingAnchor),
            heightAnchor.constraint(equalToConstant: 12),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }
}

/// Returns a green/yellow/red color matching the green-yellow-red
/// thresholds for the given fraction (0...1). Used by widgets that
/// want their headline number to mirror the capacity bar's segment
/// color.
func thresholdColor(_ fraction: Double, yellow: Double = 0.5, red: Double = 0.9) -> NSColor {
    if fraction >= red { return .systemRed }
    if fraction >= yellow { return .systemYellow }
    return .systemGreen
}

// MARK: - Segmented capacity bar

/// Horizontal segmented bar — the same shape as the Storage row in
/// System Settings. Each segment renders proportional to its bytes,
/// with a 1 pt separator between adjacent segments and one rounded
/// outer shell. Empty space at the right represents free bytes.
final class SegmentedCapacityBar: NSView {
    struct Segment {
        var color: NSColor
        var bytes: Int64
    }

    var totalBytes: Int64 = 0
    var segments: [Segment] = [] {
        didSet { needsDisplay = true }
    }
    var cornerRadius: CGFloat = 4
    var trackColor: NSColor = NSColor.white.withAlphaComponent(0.10)

    init() {
        super.init(frame: NSRect(x: 0, y: 0, width: 240, height: 12))
        wantsLayer = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override var intrinsicContentSize: NSSize {
        NSSize(width: NSView.noIntrinsicMetric, height: 12)
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        let bounds = self.bounds

        // Track.
        let trackPath = NSBezierPath(roundedRect: bounds, xRadius: cornerRadius, yRadius: cornerRadius)
        trackColor.setFill()
        trackPath.fill()

        guard totalBytes > 0 else { return }

        // Clip to rounded shell.
        NSGraphicsContext.saveGraphicsState()
        trackPath.addClip()

        var x: CGFloat = 0
        for (i, seg) in segments.enumerated() {
            guard seg.bytes > 0 else { continue }
            let w = bounds.width * CGFloat(Double(seg.bytes) / Double(totalBytes))
            let rect = NSRect(x: x, y: 0, width: w, height: bounds.height)
            seg.color.setFill()
            rect.fill()
            x += w
            // Subtle 1 pt separator between adjacent segments.
            if i < segments.count - 1, seg.bytes > 0 {
                let sep = NSRect(x: x - 0.5, y: 0, width: 1, height: bounds.height)
                NSColor.black.withAlphaComponent(0.25).setFill()
                sep.fill()
            }
        }

        NSGraphicsContext.restoreGraphicsState()
    }
}

/// Color dot + label + value on one line — the same row used by the
/// storage popover's category legend.
final class LegendRow: NSView {
    private let dot = NSView()
    private let labelField = NSTextField(labelWithString: "")
    private let valueField = NSTextField(labelWithString: "")

    init(color: NSColor, label: String, value: String = "—") {
        super.init(frame: .zero)
        dot.wantsLayer = true
        dot.layer?.backgroundColor = color.cgColor
        dot.layer?.cornerRadius = 4
        dot.translatesAutoresizingMaskIntoConstraints = false

        labelField.font = NSFont.systemFont(ofSize: 11)
        valueField.font = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .regular)
        valueField.textColor = .secondaryLabelColor
        labelField.stringValue = label
        valueField.stringValue = value

        let row = NSStackView(views: [dot, labelField, NSView(), valueField])
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 6
        row.translatesAutoresizingMaskIntoConstraints = false
        addSubview(row)
        NSLayoutConstraint.activate([
            row.topAnchor.constraint(equalTo: topAnchor),
            row.bottomAnchor.constraint(equalTo: bottomAnchor),
            row.leadingAnchor.constraint(equalTo: leadingAnchor),
            row.trailingAnchor.constraint(equalTo: trailingAnchor),
            dot.widthAnchor.constraint(equalToConstant: 8),
            dot.heightAnchor.constraint(equalToConstant: 8),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    func update(value: String) { valueField.stringValue = value }
}

// MARK: - Layout helpers

enum WidgetPopover {
    /// Builds the standard popover chrome: title + custom body + unpin
    /// button. `body` is the widget-specific content (sparkline,
    /// capacity bar, totals, etc.).
    static func wrap(title: String, body: NSView, onUnpin: @escaping () -> Void) -> NSView {
        let titleLabel = NSTextField(labelWithString: title)
        titleLabel.font = NSFont.systemFont(ofSize: 12, weight: .semibold)
        titleLabel.textColor = .secondaryLabelColor

        let unpin = NSButton(title: "Unpin", target: BlockTarget.attach(to: titleLabel, action: onUnpin), action: #selector(BlockTarget.invoke))
        unpin.bezelStyle = .accessoryBarAction
        unpin.controlSize = .small
        unpin.font = NSFont.systemFont(ofSize: 11)

        let header = NSStackView(views: [titleLabel, NSView(), unpin])
        header.orientation = .horizontal
        header.alignment = .centerY

        let stack = NSStackView(views: [header, body])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 8
        stack.edgeInsets = NSEdgeInsets(top: 10, left: 12, bottom: 10, right: 12)
        stack.translatesAutoresizingMaskIntoConstraints = false

        let container = NSView()
        container.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: container.topAnchor),
            stack.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            header.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -24),
            body.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -24),
            container.widthAnchor.constraint(greaterThanOrEqualToConstant: 260),
        ])
        return container
    }

    /// Small "Label  Value" row commonly used in detail bodies. Returns
    /// the row's value field so the caller can update it later.
    static func labeledRow(_ label: String, value: String, valueIsMono: Bool = true) -> (row: NSView, value: NSTextField) {
        let l = NSTextField(labelWithString: label)
        l.font = NSFont.systemFont(ofSize: 11)
        l.textColor = .secondaryLabelColor

        let v = NSTextField(labelWithString: value)
        v.font = valueIsMono
            ? NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .medium)
            : NSFont.systemFont(ofSize: 12, weight: .medium)

        let row = NSStackView(views: [l, NSView(), v])
        row.orientation = .horizontal
        row.alignment = .firstBaseline
        return (row, v)
    }
}

/// Tiny shim so we can attach a closure to an NSButton without
/// proliferating @objc helper objects per widget.
final class BlockTarget: NSObject {
    private let block: () -> Void
    private init(_ block: @escaping () -> Void) { self.block = block }
    @objc func invoke() { block() }

    /// Anchored to the lifetime of `owner` via associated object so it
    /// isn't deallocated immediately.
    static func attach(to owner: AnyObject, action: @escaping () -> Void) -> BlockTarget {
        let t = BlockTarget(action)
        objc_setAssociatedObject(owner, &Self.associatedKey, t, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        return t
    }
    private static var associatedKey: UInt8 = 0
}
