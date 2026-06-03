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
    private let breakdownLabel = NSTextField(labelWithString: "")
    private let userSwatch = ColorSwatch(color: .systemBlue, label: "user")
    private let systemSwatch = ColorSwatch(color: .systemRed, label: "system")
    private let spark = StackedSparkline()

    init() {
        super.init(frame: .zero)
        valueLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 28, weight: .semibold)
        breakdownLabel.font = NSFont.systemFont(ofSize: 11)
        breakdownLabel.textColor = .secondaryLabelColor

        spark.primaryColor = .systemBlue       // user — bottom band
        spark.secondaryColor = .systemRed      // system — stacked on top
        spark.yMax = 1.0
        spark.translatesAutoresizingMaskIntoConstraints = false

        let legend = NSStackView(views: [userSwatch, systemSwatch, NSView()])
        legend.orientation = .horizontal
        legend.spacing = 10
        legend.alignment = .centerY

        let headline = NSStackView(views: [valueLabel, NSView(), breakdownLabel])
        headline.orientation = .horizontal
        headline.alignment = .firstBaseline

        let stack = NSStackView(views: [headline, spark, legend])
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
            spark.widthAnchor.constraint(greaterThanOrEqualToConstant: 240),
            spark.heightAnchor.constraint(equalToConstant: 60),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    func update(current: SystemStats.CPULoad, history: [SystemStats.CPULoad]) {
        valueLabel.stringValue = String(format: "%.0f%%", current.total * 100)
        breakdownLabel.stringValue = String(
            format: "user %.0f%%  ·  system %.0f%%",
            current.user * 100, current.system * 100
        )
        spark.reset()
        for sample in history {
            spark.add(StackedSparkline.Point(primary: sample.user, secondary: sample.system))
        }
    }
}

/// Tiny legend chip: filled dot + label.
private final class ColorSwatch: NSView {
    init(color: NSColor, label: String) {
        super.init(frame: .zero)
        let dot = NSView()
        dot.wantsLayer = true
        dot.layer?.backgroundColor = color.cgColor
        dot.layer?.cornerRadius = 4
        dot.translatesAutoresizingMaskIntoConstraints = false

        let l = NSTextField(labelWithString: label)
        l.font = NSFont.systemFont(ofSize: 11)
        l.textColor = .secondaryLabelColor

        addSubview(dot)
        addSubview(l)
        l.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            dot.leadingAnchor.constraint(equalTo: leadingAnchor),
            dot.centerYAnchor.constraint(equalTo: centerYAnchor),
            dot.widthAnchor.constraint(equalToConstant: 8),
            dot.heightAnchor.constraint(equalToConstant: 8),
            l.leadingAnchor.constraint(equalTo: dot.trailingAnchor, constant: 4),
            l.centerYAnchor.constraint(equalTo: centerYAnchor),
            l.trailingAnchor.constraint(equalTo: trailingAnchor),
            heightAnchor.constraint(equalToConstant: 14),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }
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
    private let freeLabel = NSTextField(labelWithString: "— free")
    private let totalLabel = NSTextField(labelWithString: "")
    private let bar = CapacityBar()
    private let deltaLabel = NSTextField(labelWithString: "")

    private var usedRow: (row: NSView, value: NSTextField)!
    private var purgeableRow: (row: NSView, value: NSTextField)!
    private var freeRow: (row: NSView, value: NSTextField)!

    private let categoriesHeading = NSTextField(labelWithString: "Folders")
    private let categoriesStatus = NSTextField(labelWithString: "")
    private let categoriesStack = NSStackView()
    private var categoryRows: [String: NSTextField] = [:]
    private let permissionBanner = PermissionBanner()

    init() {
        super.init(frame: .zero)
        freeLabel.font = NSFont.systemFont(ofSize: 18, weight: .semibold)
        totalLabel.font = NSFont.systemFont(ofSize: 11)
        totalLabel.textColor = .secondaryLabelColor
        deltaLabel.font = NSFont.systemFont(ofSize: 11)
        deltaLabel.textColor = .secondaryLabelColor

        bar.translatesAutoresizingMaskIntoConstraints = false
        bar.thresholds = (yellow: 0.85, red: 0.95)

        usedRow = WidgetPopover.labeledRow("Used", value: "—")
        purgeableRow = WidgetPopover.labeledRow("Purgeable", value: "—")
        freeRow = WidgetPopover.labeledRow("Free", value: "—")

        let headline = NSStackView(views: [freeLabel, NSView(), totalLabel])
        headline.orientation = .horizontal
        headline.alignment = .firstBaseline

        let volumeBreakdown = NSStackView(views: [usedRow.row, purgeableRow.row, freeRow.row])
        volumeBreakdown.orientation = .vertical
        volumeBreakdown.alignment = .leading
        volumeBreakdown.spacing = 2

        categoriesHeading.font = NSFont.systemFont(ofSize: 11, weight: .semibold)
        categoriesHeading.textColor = .secondaryLabelColor
        categoriesStatus.font = NSFont.systemFont(ofSize: 10)
        categoriesStatus.textColor = .tertiaryLabelColor

        categoriesStack.orientation = .vertical
        categoriesStack.alignment = .leading
        categoriesStack.spacing = 2

        permissionBanner.configure(
            title: "Full Disk Access is off",
            body: "Folder sizes still work for ~/Documents, Downloads, Pictures, etc. Grant FDA for accurate totals on system-protected paths.",
            settingsURL: SystemPermission.fullDiskAccessSettingsURL
        )
        permissionBanner.translatesAutoresizingMaskIntoConstraints = false

        let stack = NSStackView(views: [
            headline,
            bar,
            volumeBreakdown,
            deltaLabel,
            categoriesHeading,
            categoriesStack,
            categoriesStatus,
            permissionBanner,
        ])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 6
        stack.setCustomSpacing(12, after: deltaLabel)
        stack.setCustomSpacing(4, after: categoriesHeading)
        stack.setCustomSpacing(10, after: categoriesStatus)
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
            bar.widthAnchor.constraint(greaterThanOrEqualToConstant: 280),
            usedRow.row.widthAnchor.constraint(equalTo: stack.widthAnchor),
            purgeableRow.row.widthAnchor.constraint(equalTo: stack.widthAnchor),
            freeRow.row.widthAnchor.constraint(equalTo: stack.widthAnchor),
            categoriesStack.widthAnchor.constraint(equalTo: stack.widthAnchor),
            permissionBanner.widthAnchor.constraint(equalTo: stack.widthAnchor),
        ])

        permissionBanner.setVisible(!SystemPermission.fullDiskAccessGranted())
        buildCategoryRows()
        loadCategories()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    func update(m: SystemStats.StorageBreakdown, startupFree: Int64, startupAt: Date) {
        freeLabel.stringValue = "\(SystemStats.humanBytes(m.free)) free"
        totalLabel.stringValue = "of \(SystemStats.humanBytes(m.total))"
        bar.fill = m.usedFraction

        usedRow.value.stringValue = SystemStats.humanBytes(m.used)
        purgeableRow.value.stringValue = m.purgeable == 0
            ? "none"
            : SystemStats.humanBytes(m.purgeable)
        freeRow.value.stringValue = SystemStats.humanBytes(m.free)

        let delta = m.free - startupFree
        let mins = max(1, Int(Date().timeIntervalSince(startupAt) / 60))
        let sign = delta >= 0 ? "+" : "−"
        let mag = SystemStats.humanBytes(abs(delta))
        deltaLabel.stringValue = "Δ since launch  \(sign)\(mag)  ·  \(mins) min"
    }

    private func buildCategoryRows() {
        for category in StorageCategoryScanner.shared.categories {
            let icon = NSImageView()
            icon.image = NSImage(systemSymbolName: category.symbol, accessibilityDescription: category.label)
            icon.contentTintColor = .secondaryLabelColor
            icon.imageScaling = .scaleProportionallyDown
            icon.translatesAutoresizingMaskIntoConstraints = false

            let label = NSTextField(labelWithString: category.label)
            label.font = NSFont.systemFont(ofSize: 11)

            let value = NSTextField(labelWithString: "—")
            value.font = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .regular)
            value.textColor = .secondaryLabelColor

            let row = NSStackView(views: [icon, label, NSView(), value])
            row.orientation = .horizontal
            row.alignment = .centerY
            row.spacing = 6
            NSLayoutConstraint.activate([
                icon.widthAnchor.constraint(equalToConstant: 14),
                icon.heightAnchor.constraint(equalToConstant: 14),
                row.widthAnchor.constraint(greaterThanOrEqualToConstant: 280),
            ])
            categoriesStack.addArrangedSubview(row)
            categoryRows[category.id] = value
        }
    }

    private func loadCategories() {
        categoriesStatus.stringValue = "Calculating folder sizes…"
        StorageCategoryScanner.shared.results { [weak self] results, isCached in
            guard let self = self else { return }
            for r in results {
                self.categoryRows[r.category.id]?.stringValue = SystemStats.humanBytes(r.bytes)
            }
            self.categoriesStatus.stringValue = isCached
                ? "Cached — refreshing in background…"
                : "Updated just now"
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
