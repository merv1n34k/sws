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

    /// `fill` is 0...1.
    var fill: Double = 0 {
        didSet {
            indicator.doubleValue = max(0, min(1, fill))
        }
    }

    init() {
        self.indicator = NSLevelIndicator(frame: .zero)
        super.init(frame: .zero)
        indicator.levelIndicatorStyle = .continuousCapacity
        indicator.minValue = 0
        indicator.maxValue = 1
        indicator.warningValue = 0.85
        indicator.criticalValue = 0.95
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
