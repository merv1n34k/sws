import AppKit

/// Concrete menu-bar widgets backed by SystemStats / WiFiInfo /
/// NetworkInfo. Each widget renders a compact two-line status item and
/// owns a richer `detailView()` shown in a popover on click.
///
/// All `render()` outputs are sized through a per-widget reservation
/// width so that values changing (12% → 100%, 95 KB/s → 1.2 MB/s)
/// don't shift the rest of the menu-bar stack.

private let topFont = NSFont.systemFont(ofSize: 8, weight: .semibold)
private let valueFont = NSFont.monospacedDigitSystemFont(ofSize: 9, weight: .medium)

private func reserveWidth(top: String, longestBottom: String) -> CGFloat {
    let a = (top as NSString).size(withAttributes: [.font: topFont]).width
    let b = (longestBottom as NSString).size(withAttributes: [.font: valueFont]).width
    return ceil(max(a, b)) + 4
}

// MARK: - CPU

final class CPUWidget: MenuBarWidget {
    let id = "cpu"
    let detailTitle = "CPU"
    let pollInterval: TimeInterval = 2
    private let sampler = SystemStats.CPUSampler()
    private var lastValue = "  0%"
    private var history: [SystemStats.CPULoad] = []
    private weak var detail: CPUDetailView?
    private static let reserved = reserveWidth(top: "CPU", longestBottom: "100%")

    func render() -> MenuBarRendering {
        let load = sampler.sample()
        history.append(load)
        if history.count > 120 { history.removeFirst(history.count - 120) }
        let total = (load.total * 100).rounded()
        lastValue = String(format: "%3d%%", max(0, min(100, Int(total))))
        detail?.update(current: load, history: history)
        return .twoLines(top: "CPU", bottom: lastValue, minWidth: Self.reserved)
    }
    func currentValue() -> String { lastValue.trimmingCharacters(in: .whitespaces) }

    func detailView() -> NSView? {
        let v = CPUDetailView()
        v.update(current: history.last ?? SystemStats.CPULoad(user: 0, system: 0), history: history)
        detail = v
        return v
    }
}

private final class CPUDetailView: NSView {
    private let valueLabel = NSTextField(labelWithString: "—%")
    private let userValue = NSTextField(labelWithString: "—%")
    private let systemValue = NSTextField(labelWithString: "—%")
    private let spark = StackedSparkline()

    init() {
        super.init(frame: .zero)
        valueLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 28, weight: .semibold)
        userValue.font = NSFont.systemFont(ofSize: 11)
        userValue.textColor = .secondaryLabelColor
        systemValue.font = NSFont.systemFont(ofSize: 11)
        systemValue.textColor = .secondaryLabelColor

        spark.primaryColor = .systemBlue       // user — bottom band
        spark.secondaryColor = .systemRed      // system — stacked on top
        spark.yMax = 1.0
        spark.translatesAutoresizingMaskIntoConstraints = false

        // Inline legend — color dot sits immediately to the left of
        // each value so the breakdown reads as one row.
        let userChip = inlineChip(color: .systemBlue, label: "user", valueField: userValue)
        let systemChip = inlineChip(color: .systemRed, label: "system", valueField: systemValue)

        let breakdownRow = NSStackView(views: [userChip, systemChip, NSView()])
        breakdownRow.orientation = .horizontal
        breakdownRow.spacing = 14
        breakdownRow.alignment = .centerY

        let headline = NSStackView(views: [valueLabel, NSView(), breakdownRow])
        headline.orientation = .horizontal
        headline.alignment = .firstBaseline
        headline.spacing = 8

        let stack = NSStackView(views: [headline, spark])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 6
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
            spark.widthAnchor.constraint(greaterThanOrEqualToConstant: 280),
            spark.heightAnchor.constraint(equalToConstant: 60),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    func update(current: SystemStats.CPULoad, history: [SystemStats.CPULoad]) {
        valueLabel.stringValue = String(format: "%.0f%%", current.total * 100)
        userValue.stringValue = String(format: "user %.0f%%", current.user * 100)
        systemValue.stringValue = String(format: "system %.0f%%", current.system * 100)
        spark.reset()
        for sample in history {
            spark.add(StackedSparkline.Point(primary: sample.user, secondary: sample.system))
        }
    }

    /// Color dot + value field rendered as one horizontal row.
    /// `label` is folded into the value field text (e.g. "user 23%"),
    /// so we only need the dot to sit beside it.
    private func inlineChip(color: NSColor, label: String, valueField: NSTextField) -> NSView {
        let dot = NSView()
        dot.wantsLayer = true
        dot.layer?.backgroundColor = color.cgColor
        dot.layer?.cornerRadius = 4
        dot.translatesAutoresizingMaskIntoConstraints = false

        let row = NSStackView(views: [dot, valueField])
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 5
        NSLayoutConstraint.activate([
            dot.widthAnchor.constraint(equalToConstant: 8),
            dot.heightAnchor.constraint(equalToConstant: 8),
        ])
        return row
    }
}

// MARK: - RAM

final class RAMWidget: MenuBarWidget {
    let id = "ram"
    let detailTitle = "Memory"
    let pollInterval: TimeInterval = 3
    private var lastValue = "  0%"
    private var history: [Double] = []
    private var lastBreakdown: SystemStats.MemoryBreakdown?
    private weak var detail: RAMDetailView?
    private static let reserved = reserveWidth(top: "RAM", longestBottom: "100%")

    func render() -> MenuBarRendering {
        let m = SystemStats.memoryBreakdown()
        lastBreakdown = m
        let pct = m.usedFraction * 100
        history.append(pct)
        if history.count > 120 { history.removeFirst(history.count - 120) }
        lastValue = String(format: "%3d%%", Int(pct.rounded()))
        detail?.update(m: m, history: history)
        return .twoLines(top: "RAM", bottom: lastValue, minWidth: Self.reserved)
    }
    func currentValue() -> String { lastValue.trimmingCharacters(in: .whitespaces) }

    func detailView() -> NSView? {
        let v = RAMDetailView()
        if let m = lastBreakdown {
            v.update(m: m, history: history)
        }
        detail = v
        return v
    }
}

private final class RAMDetailView: NSView {
    private let valueLabel = NSTextField(labelWithString: "—%")
    private let totalLabel = NSTextField(labelWithString: "")
    private let bar = CapacityBar()
    private let spark = Sparkline()

    private var wiredRow: (row: NSView, value: NSTextField)!
    private var compressedRow: (row: NSView, value: NSTextField)!
    private var cachedRow: (row: NSView, value: NSTextField)!
    private var swapRow: (row: NSView, value: NSTextField)!

    init() {
        super.init(frame: .zero)
        valueLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 28, weight: .semibold)
        totalLabel.font = NSFont.systemFont(ofSize: 11)
        totalLabel.textColor = .secondaryLabelColor

        spark.yRange = 0...100
        spark.translatesAutoresizingMaskIntoConstraints = false

        bar.translatesAutoresizingMaskIntoConstraints = false
        // User-requested thresholds — green up to 50%, yellow up to
        // 90%, red beyond.
        bar.thresholds = (yellow: 0.5, red: 0.9)

        wiredRow = WidgetPopover.labeledRow("Wired", value: "—")
        compressedRow = WidgetPopover.labeledRow("Compressed", value: "—")
        cachedRow = WidgetPopover.labeledRow("Cached files", value: "—")
        swapRow = WidgetPopover.labeledRow("Swap used", value: "—")

        let headline = NSStackView(views: [valueLabel, NSView(), totalLabel])
        headline.orientation = .horizontal
        headline.alignment = .firstBaseline

        let categories = NSStackView(views: [wiredRow.row, compressedRow.row, cachedRow.row, swapRow.row])
        categories.orientation = .vertical
        categories.alignment = .leading
        categories.spacing = 2

        let stack = NSStackView(views: [headline, bar, spark, categories])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
            bar.widthAnchor.constraint(greaterThanOrEqualToConstant: 240),
            spark.widthAnchor.constraint(greaterThanOrEqualToConstant: 240),
            spark.heightAnchor.constraint(equalToConstant: 60),
            wiredRow.row.widthAnchor.constraint(equalTo: stack.widthAnchor),
            compressedRow.row.widthAnchor.constraint(equalTo: stack.widthAnchor),
            cachedRow.row.widthAnchor.constraint(equalTo: stack.widthAnchor),
            swapRow.row.widthAnchor.constraint(equalTo: stack.widthAnchor),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    func update(m: SystemStats.MemoryBreakdown, history: [Double]) {
        let frac = m.usedFraction
        let pct = frac * 100
        let tint = thresholdColor(frac, yellow: 0.5, red: 0.9)

        valueLabel.stringValue = String(format: "%.0f%%", pct)
        valueLabel.textColor = tint
        totalLabel.stringValue = "\(SystemStats.humanBytes(Int64(m.used))) / \(SystemStats.humanBytes(Int64(m.total)))"
        bar.fill = frac
        spark.lineColor = tint
        spark.fillColor = tint.withAlphaComponent(0.18)
        spark.reset()
        for v in history { spark.add(v) }

        wiredRow.value.stringValue = SystemStats.humanBytes(Int64(m.wired))
        compressedRow.value.stringValue = SystemStats.humanBytes(Int64(m.compressed))
        cachedRow.value.stringValue = SystemStats.humanBytes(Int64(m.cached))
        swapRow.value.stringValue = m.swapUsed == 0
            ? "none"
            : SystemStats.humanBytes(Int64(m.swapUsed))
    }
}

// MARK: - Storage

final class DiskWidget: MenuBarWidget {
    let id = "space"
    let detailTitle = "Storage"
    let pollInterval: TimeInterval = 30
    private var lastValue = "   —"
    private var lastBreakdown: SystemStats.StorageBreakdown?
    private var startupFree: Int64?
    private var startupAt = Date()
    private weak var detail: DiskDetailView?
    private static let reserved = reserveWidth(top: "SSD", longestBottom: "999 GB")

    func render() -> MenuBarRendering {
        let m = SystemStats.storageBreakdown()
        lastBreakdown = m
        if startupFree == nil { startupFree = m.free }
        lastValue = SystemStats.humanBytesShort(m.free)
        detail?.update(m: m, startupFree: startupFree ?? m.free, startupAt: startupAt)
        return .twoLines(top: "SSD", bottom: lastValue, minWidth: Self.reserved)
    }
    func currentValue() -> String { lastValue.trimmingCharacters(in: .whitespaces) }

    func detailView() -> NSView? {
        let v = DiskDetailView()
        if let m = lastBreakdown {
            v.update(m: m, startupFree: startupFree ?? m.free, startupAt: startupAt)
        }
        detail = v
        return v
    }
}

private final class DiskDetailView: NSView {
    /// Number of legend rows shown beneath the bar.
    private static let legendTopN = 5

    private let headlineLabel = NSTextField(labelWithString: "—")
    private let bar = SegmentedCapacityBar()
    private let statusLabel = NSTextField(labelWithString: "")
    private let legendStack = NSStackView()
    private let permissionBanner = PermissionBanner()
    private var lastUsedBytes: Int64 = 0

    init() {
        super.init(frame: .zero)
        headlineLabel.font = NSFont.systemFont(ofSize: 13, weight: .semibold)
        headlineLabel.maximumNumberOfLines = 2

        bar.translatesAutoresizingMaskIntoConstraints = false

        statusLabel.font = NSFont.systemFont(ofSize: 10)
        statusLabel.textColor = .tertiaryLabelColor

        legendStack.orientation = .vertical
        legendStack.alignment = .leading
        legendStack.spacing = 2

        permissionBanner.configure(
            title: "Full Disk Access is off",
            body: "Categories still work for /Applications and your home folders. Grant FDA for accurate Library and tmp totals.",
            settingsURL: SystemPermission.fullDiskAccessSettingsURL
        )
        permissionBanner.translatesAutoresizingMaskIntoConstraints = false

        let stack = NSStackView(views: [
            headlineLabel,
            bar,
            legendStack,
            statusLabel,
            permissionBanner,
        ])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 8
        stack.setCustomSpacing(6, after: bar)
        stack.setCustomSpacing(10, after: statusLabel)
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
            bar.widthAnchor.constraint(equalTo: stack.widthAnchor),
            bar.heightAnchor.constraint(equalToConstant: 12),
            legendStack.widthAnchor.constraint(equalTo: stack.widthAnchor),
            permissionBanner.widthAnchor.constraint(equalTo: stack.widthAnchor),
            stack.widthAnchor.constraint(greaterThanOrEqualToConstant: 300),
        ])

        permissionBanner.setVisible(!SystemPermission.fullDiskAccessGranted())
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    func update(m: SystemStats.StorageBreakdown, startupFree: Int64, startupAt: Date) {
        lastUsedBytes = m.used
        let delta = m.free - startupFree
        let deltaPart: String
        if abs(delta) < 1024 * 1024 {
            deltaPart = ""
        } else {
            let sign = delta >= 0 ? "+" : "−"
            deltaPart = "  ·  Δ \(sign)\(SystemStats.humanBytes(abs(delta)))"
        }
        headlineLabel.stringValue =
            "\(SystemStats.humanBytes(m.free)) free of \(SystemStats.humanBytes(m.total))\(deltaPart)"
        bar.totalBytes = m.total
        loadCategories()
    }

    private func loadCategories() {
        statusLabel.stringValue = "Calculating folder sizes…"
        StorageCategoryScanner.shared.results(usedBytes: lastUsedBytes) { [weak self] results, isCached in
            guard let self = self else { return }
            self.applyCategories(results)
            self.statusLabel.stringValue = isCached
                ? "Cached — refreshing in background…"
                : "Updated just now"
        }
    }

    private func applyCategories(_ results: [StorageCategoryScanner.Result]) {
        // Segments use the canonical scanner order so colors stay
        // anchored even as proportions shift.
        bar.segments = results.map {
            SegmentedCapacityBar.Segment(color: $0.category.color, bytes: $0.bytes)
        }

        // Legend lists the top N by size — kept to a minimal vertical
        // strip per the "no click/hover" rule.
        let top = results
            .filter { $0.bytes > 0 }
            .sorted(by: { $0.bytes > $1.bytes })
            .prefix(Self.legendTopN)

        for sub in legendStack.arrangedSubviews {
            legendStack.removeArrangedSubview(sub)
            sub.removeFromSuperview()
        }
        for r in top {
            let row = LegendRow(
                color: r.category.color,
                label: r.category.label,
                value: SystemStats.humanBytes(r.bytes)
            )
            row.translatesAutoresizingMaskIntoConstraints = false
            legendStack.addArrangedSubview(row)
            row.widthAnchor.constraint(equalTo: legendStack.widthAnchor).isActive = true
        }
    }
}

// MARK: - Network

final class NetworkWidget: MenuBarWidget {
    let id = "network"
    let detailTitle = "Network"
    let pollInterval: TimeInterval = 1
    private let sampler = SystemStats.NetworkSampler()
    private var lastDown = "  0 KB/s"
    private var lastUp = "  0 KB/s"
    /// Cumulative bytes since launch — accumulated from the sampler's
    /// per-second rate. Resets on app restart.
    private var totalDown: Double = 0
    private var totalUp: Double = 0
    private var sessionStart = Date()
    private var lastSampleTime = Date()
    private weak var detail: NetworkDetailView?
    private static let reserved = reserveWidth(top: "↑ 999 MB/s", longestBottom: "↓ 999 MB/s")

    func render() -> MenuBarRendering {
        let (down, up) = sampler.sample()
        let now = Date()
        let dt = now.timeIntervalSince(lastSampleTime)
        if dt > 0 && dt < 5 {
            totalDown += down * dt
            totalUp += up * dt
        }
        lastSampleTime = now
        lastUp = "↑ " + SystemStats.humanRateFixed(up)
        lastDown = "↓ " + SystemStats.humanRateFixed(down)
        detail?.update(down: down, up: up, totalDown: totalDown, totalUp: totalUp, since: sessionStart)
        return .twoLines(top: lastUp, bottom: lastDown, minWidth: Self.reserved)
    }
    func currentValue() -> String { "\(lastUp)  \(lastDown)" }

    func detailView() -> NSView? {
        let v = NetworkDetailView()
        v.update(down: 0, up: 0, totalDown: totalDown, totalUp: totalUp, since: sessionStart)
        detail = v
        return v
    }
}

private final class NetworkDetailView: NSView {
    private let downNow = NSTextField(labelWithString: "↓ —")
    private let upNow = NSTextField(labelWithString: "↑ —")
    private let downTotal = NSTextField(labelWithString: "")
    private let upTotal = NSTextField(labelWithString: "")
    private let sinceLabel = NSTextField(labelWithString: "")

    init() {
        super.init(frame: .zero)
        for f in [downNow, upNow] {
            f.font = NSFont.monospacedDigitSystemFont(ofSize: 14, weight: .semibold)
        }
        for f in [downTotal, upTotal] {
            f.font = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .medium)
            f.textColor = .secondaryLabelColor
        }
        sinceLabel.font = NSFont.systemFont(ofSize: 11)
        sinceLabel.textColor = .secondaryLabelColor

        let nowRow = NSStackView(views: [downNow, upNow])
        nowRow.orientation = .horizontal
        nowRow.spacing = 12
        nowRow.alignment = .firstBaseline

        let totalRow = NSStackView(views: [downTotal, upTotal])
        totalRow.orientation = .horizontal
        totalRow.spacing = 12
        totalRow.alignment = .firstBaseline

        let stack = NSStackView(views: [nowRow, totalRow, sinceLabel])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 6
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
            stack.widthAnchor.constraint(greaterThanOrEqualToConstant: 240),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    func update(down: Double, up: Double, totalDown: Double, totalUp: Double, since: Date) {
        downNow.stringValue = "↓ " + SystemStats.humanRate(down)
        upNow.stringValue = "↑ " + SystemStats.humanRate(up)
        downTotal.stringValue = "↓ session  " + SystemStats.humanBytes(Int64(totalDown))
        upTotal.stringValue = "↑ session  " + SystemStats.humanBytes(Int64(totalUp))
        let mins = max(1, Int(Date().timeIntervalSince(since) / 60))
        sinceLabel.stringValue = "since launch  ·  \(mins) min"
    }
}

// MARK: - IP

final class IPWidget: MenuBarWidget {
    let id = "ip"
    let detailTitle = "Network address"
    let pollInterval: TimeInterval = 60
    private weak var detail: IPDetailView?
    private static let reserved = reserveWidth(top: "VPN", longestBottom: "255.255.255.255")

    func render() -> MenuBarRendering {
        if let ip = NetworkInfo.shared.publicIP {
            detail?.update()
            return .twoLines(
                top: NetworkInfo.shared.vpnLikely() ? "VPN" : "IP",
                bottom: ip,
                minWidth: Self.reserved
            )
        }
        NetworkInfo.shared.refreshPublicIP()
        return .twoLines(top: "IP", bottom: "…", minWidth: Self.reserved)
    }

    func currentValue() -> String { NetworkInfo.shared.publicIP ?? "…" }

    func detailView() -> NSView? {
        let v = IPDetailView()
        v.update()
        detail = v
        return v
    }
}

private final class IPDetailView: NSView {
    private let publicLabel = NSTextField(labelWithString: "—")
    private let localLabel = NSTextField(labelWithString: "—")
    private let vpnLabel = NSTextField(labelWithString: "")
    private let refreshButton = NSButton(title: "Refresh", target: nil, action: nil)

    init() {
        super.init(frame: .zero)
        publicLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 14, weight: .semibold)
        localLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .regular)
        localLabel.textColor = .secondaryLabelColor
        vpnLabel.font = NSFont.systemFont(ofSize: 11)
        vpnLabel.textColor = .secondaryLabelColor

        refreshButton.bezelStyle = .accessoryBarAction
        refreshButton.controlSize = .small
        refreshButton.target = self
        refreshButton.action = #selector(refresh)

        let header = WidgetPopover.labeledRow("Public", value: "—")
        let localRow = WidgetPopover.labeledRow("Local", value: "—")

        let stack = NSStackView(views: [header.row, localRow.row, vpnLabel, refreshButton])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 4
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
            stack.widthAnchor.constraint(greaterThanOrEqualToConstant: 240),
            header.row.widthAnchor.constraint(equalTo: stack.widthAnchor),
            localRow.row.widthAnchor.constraint(equalTo: stack.widthAnchor),
        ])
        publicLabel.removeFromSuperview()
        localLabel.removeFromSuperview()
        self.publicValue = header.value
        self.localValue = localRow.value
    }

    private var publicValue: NSTextField!
    private var localValue: NSTextField!

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    @objc func refresh() {
        NetworkInfo.shared.refreshPublicIP { [weak self] _ in self?.update() }
    }

    func update() {
        publicValue.stringValue = NetworkInfo.shared.publicIP ?? "…"
        localValue.stringValue = NetworkInfo.shared.localIPv4() ?? "—"
        vpnLabel.stringValue = NetworkInfo.shared.vpnLikely() ? "VPN-like routing detected" : ""
    }
}

// MARK: - Wi-Fi

final class WiFiWidget: MenuBarWidget {
    let id = "wifi"
    let detailTitle = "Wi-Fi"
    let pollInterval: TimeInterval = 5
    private weak var detail: WiFiDetailView?
    private static let reserved = reserveWidth(top: "Wi-Fi", longestBottom: "MyNetworkName")

    func render() -> MenuBarRendering {
        let snap = WiFiInfo.current()
        detail?.update(snap)
        if let ssid = snap.ssid {
            let rssi = snap.rssi.map { "\($0)dB" } ?? ""
            return .twoLines(top: ssid, bottom: rssi, minWidth: Self.reserved)
        }
        return .twoLines(top: "Wi-Fi", bottom: "—", minWidth: Self.reserved)
    }

    func currentValue() -> String {
        let s = WiFiInfo.current()
        guard let ssid = s.ssid else { return "—" }
        return s.rssi.map { "\(ssid)  \($0) dBm" } ?? ssid
    }

    func detailView() -> NSView? {
        let v = WiFiDetailView()
        v.update(WiFiInfo.current())
        detail = v
        return v
    }
}

private final class WiFiDetailView: NSView {
    private var ssidValue: NSTextField!
    private var rssiValue: NSTextField!
    private var channelValue: NSTextField!

    init() {
        super.init(frame: .zero)
        let ssid = WidgetPopover.labeledRow("SSID", value: "—")
        let rssi = WidgetPopover.labeledRow("Signal", value: "—")
        let channel = WidgetPopover.labeledRow("Channel", value: "—")
        ssidValue = ssid.value
        rssiValue = rssi.value
        channelValue = channel.value

        let stack = NSStackView(views: [ssid.row, rssi.row, channel.row])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 4
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
            stack.widthAnchor.constraint(greaterThanOrEqualToConstant: 240),
            ssid.row.widthAnchor.constraint(equalTo: stack.widthAnchor),
            rssi.row.widthAnchor.constraint(equalTo: stack.widthAnchor),
            channel.row.widthAnchor.constraint(equalTo: stack.widthAnchor),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    func update(_ s: WiFiInfo.Snapshot) {
        ssidValue.stringValue = s.ssid ?? "not connected"
        rssiValue.stringValue = s.rssi.map { "\($0) dBm" } ?? "—"
        channelValue.stringValue = s.channel.map { "\($0)" } ?? "—"
    }
}

/// Catalogue of widget ids the Status mode shows as buttons.
enum StatusWidgetID: String, CaseIterable {
    case space, cpu, network, ram

    var label: String {
        switch self {
        case .space:   return "Space"
        case .cpu:     return "CPU"
        case .network: return "Net"
        case .ram:     return "RAM"
        }
    }

    func makeWidget() -> MenuBarWidget {
        switch self {
        case .space:   return DiskWidget()
        case .cpu:     return CPUWidget()
        case .network: return NetworkWidget()
        case .ram:     return RAMWidget()
        }
    }
}
