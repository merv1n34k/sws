import AppKit

/// "Old phone keyboard" layout. Top: informational rows (ports
/// lookup, HTTP code lookup, IP/VPN, Wi-Fi). Bottom: button grid
/// where each button shows a live stat and toggles its menu-bar pin.
final class StatusView: NSView, NSTextFieldDelegate {
    private let portsSearch = NSTextField()
    private let portsResult = NSTextField(labelWithString: "")
    private let httpSearch = NSTextField()
    private let httpResult = NSTextField(labelWithString: "")
    private let ipLabel = NSTextField(labelWithString: "—")
    private let wifiLabel = NSTextField(labelWithString: "—")
    private var buttons: [StatusWidgetID: StatusStatButton] = [:]
    private var timer: Timer?
    private var pinObserver: NSObjectProtocol?

    init() {
        super.init(frame: .zero)
        wantsLayer = true
        layer?.backgroundColor = NSColor(white: 0.1, alpha: 1).cgColor

        buildLayout()
        wire()
        refresh()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    deinit {
        timer?.invalidate()
        if let observer = pinObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window != nil {
            startTimer()
            refresh()
        } else {
            timer?.invalidate()
            timer = nil
        }
    }

    private func buildLayout() {
        portsSearch.placeholderString = "Ports — number or name"
        portsSearch.delegate = self
        httpSearch.placeholderString = "HTTP — number or word"
        httpSearch.delegate = self

        for field in [portsResult, httpResult, ipLabel, wifiLabel] {
            field.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
            field.textColor = .white
            field.maximumNumberOfLines = 2
            field.lineBreakMode = .byTruncatingTail
        }

        let portsRow = lookupRow(label: "Ports", search: portsSearch, result: portsResult)
        let httpRow = lookupRow(label: "HTTP",  search: httpSearch,  result: httpResult)

        let ipRow = readoutRow(label: "IP",    field: ipLabel)
        let wifiRow = readoutRow(label: "Wi-Fi", field: wifiLabel)

        let topPanel = NSStackView(views: [portsRow, httpRow, ipRow, wifiRow])
        topPanel.orientation = .vertical
        topPanel.alignment = .left
        topPanel.spacing = 8
        topPanel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(topPanel)

        let separator = NSBox()
        separator.boxType = .separator
        separator.translatesAutoresizingMaskIntoConstraints = false
        addSubview(separator)

        // Button grid (2 per row, fixed cell width so values can grow
        // without resizing the layout).
        let grid = NSGridView()
        grid.translatesAutoresizingMaskIntoConstraints = false
        grid.rowSpacing = 8
        grid.columnSpacing = 8
        grid.xPlacement = .leading
        grid.yPlacement = .fill

        var current: [StatusStatButton] = []
        for kind in StatusWidgetID.allCases {
            let btn = StatusStatButton(kind: kind) { [weak self] kind in
                MenuBarWidgetRegistry.shared.togglePinned(id: kind.rawValue)
                self?.refresh()
            }
            buttons[kind] = btn
            current.append(btn)
            if current.count == 2 {
                grid.addRow(with: current.map { $0 as NSView })
                current.removeAll()
            }
        }
        if !current.isEmpty {
            while current.count < 2 { current.append(StatusStatButton.placeholder()) }
            grid.addRow(with: current.map { $0 as NSView })
        }
        addSubview(grid)

        NSLayoutConstraint.activate([
            topPanel.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            topPanel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            topPanel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),

            separator.topAnchor.constraint(equalTo: topPanel.bottomAnchor, constant: 14),
            separator.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            separator.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),

            grid.topAnchor.constraint(equalTo: separator.bottomAnchor, constant: 14),
            grid.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            grid.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
            grid.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor, constant: -14),
        ])
    }

    private func wire() {
        pinObserver = NotificationCenter.default.addObserver(
            forName: MenuBarWidgetRegistry.didChangeNotification,
            object: nil, queue: .main
        ) { [weak self] _ in self?.updatePinStates() }
    }

    private func startTimer() {
        timer?.invalidate()
        let t = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.refresh()
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    func refresh() {
        // Stat buttons
        for (_, btn) in buttons {
            btn.updateValue()
        }
        // IP / Wi-Fi readouts
        let local = NetworkInfo.shared.localIPv4() ?? "—"
        if let pub = NetworkInfo.shared.publicIP {
            let vpn = NetworkInfo.shared.vpnLikely() ? " (VPN)" : ""
            ipLabel.stringValue = "local \(local)  ·  public \(pub)\(vpn)"
        } else {
            ipLabel.stringValue = "local \(local)  ·  public …"
            NetworkInfo.shared.refreshPublicIP { [weak self] _ in self?.refresh() }
        }
        let wifi = WiFiInfo.current()
        if let ssid = wifi.ssid {
            let rssi = wifi.rssi.map { "  \($0) dBm" } ?? ""
            let chan = wifi.channel.map { "  ch \($0)" } ?? ""
            wifiLabel.stringValue = "\(ssid)\(rssi)\(chan)"
        } else {
            wifiLabel.stringValue = "not connected"
        }
        updatePinStates()
    }

    private func updatePinStates() {
        for (kind, btn) in buttons {
            btn.setPinned(MenuBarWidgetRegistry.shared.isPinned(id: kind.rawValue))
        }
    }

    // MARK: - Lookup search

    func controlTextDidChange(_ obj: Notification) {
        guard let field = obj.object as? NSTextField else { return }
        if field === portsSearch {
            let matches = Lookups.searchPorts(field.stringValue)
            portsResult.stringValue = matches.isEmpty
                ? (field.stringValue.isEmpty ? "" : "(no match)")
                : matches.prefix(3)
                    .map { "\($0.port)  \($0.name) — \($0.description)" }
                    .joined(separator: "\n")
        } else if field === httpSearch {
            let matches = Lookups.searchHTTP(field.stringValue)
            httpResult.stringValue = matches.isEmpty
                ? (field.stringValue.isEmpty ? "" : "(no match)")
                : matches.prefix(3)
                    .map { "\($0.code)  \($0.reason) — \($0.description)" }
                    .joined(separator: "\n")
        }
    }

    // MARK: - Helpers

    private func lookupRow(label: String, search: NSTextField, result: NSTextField) -> NSView {
        let l = sectionLabel(label)
        l.widthAnchor.constraint(equalToConstant: 50).isActive = true
        let inner = NSStackView(views: [search, result])
        inner.orientation = .vertical
        inner.alignment = .left
        inner.spacing = 2
        search.widthAnchor.constraint(equalToConstant: 360).isActive = true
        let row = NSStackView(views: [l, inner])
        row.orientation = .horizontal
        row.alignment = .firstBaseline
        row.spacing = 8
        return row
    }

    private func readoutRow(label: String, field: NSTextField) -> NSView {
        let l = sectionLabel(label)
        l.widthAnchor.constraint(equalToConstant: 50).isActive = true
        let row = NSStackView(views: [l, field])
        row.orientation = .horizontal
        row.alignment = .firstBaseline
        row.spacing = 8
        return row
    }

    private func sectionLabel(_ s: String) -> NSTextField {
        let l = NSTextField(labelWithString: s)
        l.font = NSFont.systemFont(ofSize: 11, weight: .medium)
        l.textColor = .secondaryLabelColor
        l.alignment = .right
        return l
    }
}

// MARK: - Phone-keyboard style button

final class StatusStatButton: NSView {
    private let kind: StatusWidgetID
    private let labelField: NSTextField
    private let valueField: NSTextField
    private let action: (StatusWidgetID) -> Void
    private var pinned = false
    private var widget: MenuBarWidget?

    init(kind: StatusWidgetID, action: @escaping (StatusWidgetID) -> Void) {
        self.kind = kind
        self.action = action
        self.labelField = NSTextField(labelWithString: kind.label)
        self.valueField = NSTextField(labelWithString: "…")
        super.init(frame: .zero)
        wantsLayer = true
        layer?.cornerRadius = 8
        layer?.borderWidth = 1
        layer?.borderColor = NSColor(white: 0.25, alpha: 1).cgColor
        layer?.backgroundColor = NSColor(white: 0.15, alpha: 1).cgColor

        labelField.font = NSFont.systemFont(ofSize: 11, weight: .medium)
        labelField.textColor = .secondaryLabelColor
        labelField.alignment = .center

        valueField.font = NSFont.monospacedDigitSystemFont(ofSize: 13, weight: .medium)
        valueField.textColor = .white
        valueField.alignment = .center
        valueField.maximumNumberOfLines = 1
        valueField.lineBreakMode = .byTruncatingTail

        let stack = NSStackView(views: [labelField, valueField])
        stack.orientation = .vertical
        stack.spacing = 2
        stack.alignment = .centerX
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: 60),
            widthAnchor.constraint(equalToConstant: 200),
            stack.centerXAnchor.constraint(equalTo: centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: centerYAnchor),
            stack.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 4),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -4),
        ])

        widget = kind.makeWidget()
    }

    static func placeholder() -> StatusStatButton {
        // An "empty" cell to keep the grid uniform when items aren't a
        // multiple of the column count.
        let p = StatusStatButton(kind: .cpu, action: { _ in })
        p.isHidden = true
        return p
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override func mouseDown(with event: NSEvent) {
        // Visual feedback
        layer?.backgroundColor = NSColor(white: 0.25, alpha: 1).cgColor
    }

    override func mouseUp(with event: NSEvent) {
        applyAppearance()
        action(kind)
    }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .pointingHand)
    }

    func updateValue() {
        guard let widget = widget else { return }
        // render() also samples — important for CPU/Network deltas.
        _ = widget.render()
        valueField.stringValue = widget.currentValue()
    }

    func setPinned(_ pinned: Bool) {
        self.pinned = pinned
        applyAppearance()
    }

    private func applyAppearance() {
        if pinned {
            layer?.backgroundColor = NSColor.systemBlue.withAlphaComponent(0.25).cgColor
            layer?.borderColor = NSColor.systemBlue.cgColor
        } else {
            layer?.backgroundColor = NSColor(white: 0.15, alpha: 1).cgColor
            layer?.borderColor = NSColor(white: 0.25, alpha: 1).cgColor
        }
    }
}
