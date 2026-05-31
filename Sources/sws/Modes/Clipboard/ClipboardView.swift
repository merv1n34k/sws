import AppKit

final class ClipboardView: NSView, NSTableViewDataSource, NSTableViewDelegate {
    private let searchField = NSSearchField()
    private let scroll = NSScrollView()
    private let table = NSTableView()
    private let emptyLabel = NSTextField(labelWithString: "No clipboard history yet — copy something.")

    private var filter: String = ""
    private var entries: [ClipboardEntry] = []
    private var observer: NSObjectProtocol?
    private let relTimeFormatter: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .short
        return f
    }()

    init() {
        super.init(frame: .zero)
        wantsLayer = true
        layer?.backgroundColor = NSColor(white: 0.1, alpha: 1).cgColor

        searchField.placeholderString = "Search"
        searchField.delegate = self
        searchField.translatesAutoresizingMaskIntoConstraints = false
        addSubview(searchField)

        let col = NSTableColumn(identifier: .init("preview"))
        col.title = ""
        col.resizingMask = [.autoresizingMask, .userResizingMask]
        table.addTableColumn(col)
        table.headerView = nil
        table.usesAlternatingRowBackgroundColors = false
        table.backgroundColor = NSColor(white: 0.12, alpha: 1)
        table.rowHeight = 36
        table.intercellSpacing = NSSize(width: 0, height: 1)
        table.dataSource = self
        table.delegate = self
        table.allowsMultipleSelection = false
        table.target = self
        table.doubleAction = #selector(putBackSelected)
        table.menu = makeRowMenu()

        scroll.documentView = table
        scroll.hasVerticalScroller = true
        scroll.borderType = .noBorder
        scroll.wantsLayer = true
        scroll.layer?.cornerRadius = 8
        scroll.layer?.masksToBounds = true
        scroll.translatesAutoresizingMaskIntoConstraints = false
        scroll.drawsBackground = false
        addSubview(scroll)

        emptyLabel.alignment = .center
        emptyLabel.textColor = .secondaryLabelColor
        emptyLabel.font = NSFont.systemFont(ofSize: 12)
        emptyLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(emptyLabel)

        NSLayoutConstraint.activate([
            searchField.topAnchor.constraint(equalTo: topAnchor, constant: 10),
            searchField.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            searchField.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            scroll.topAnchor.constraint(equalTo: searchField.bottomAnchor, constant: 8),
            scroll.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -12),
            scroll.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            scroll.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            emptyLabel.centerXAnchor.constraint(equalTo: scroll.centerXAnchor),
            emptyLabel.centerYAnchor.constraint(equalTo: scroll.centerYAnchor),
        ])

        observer = NotificationCenter.default.addObserver(
            forName: ClipboardMonitor.didChangeNotification,
            object: nil, queue: .main
        ) { [weak self] _ in self?.refresh() }

        refresh()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    deinit {
        if let observer = observer {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    func refresh() {
        let all = ClipboardMonitor.shared.history.entries
        if filter.isEmpty {
            entries = all
        } else {
            let needle = filter.lowercased()
            entries = all.filter { entry in
                entry.preview.lowercased().contains(needle)
                    || (entry.textBody?.lowercased().contains(needle) ?? false)
            }
        }
        emptyLabel.isHidden = !entries.isEmpty
        table.reloadData()
    }

    private func makeRowMenu() -> NSMenu {
        let menu = NSMenu()
        menu.addItem(withTitle: "Copy", action: #selector(putBackSelected), keyEquivalent: "")
        menu.addItem(withTitle: "Delete", action: #selector(deleteSelected), keyEquivalent: "")
        menu.addItem(NSMenuItem.separator())
        menu.addItem(withTitle: "Clear all", action: #selector(clearAll), keyEquivalent: "")
        for item in menu.items { item.target = self }
        return menu
    }

    @objc private func putBackSelected() {
        let row = table.clickedRow >= 0 ? table.clickedRow : table.selectedRow
        guard row >= 0, row < entries.count else { return }
        ClipboardMonitor.shared.putBack(id: entries[row].id)
    }

    @objc private func deleteSelected() {
        let row = table.clickedRow >= 0 ? table.clickedRow : table.selectedRow
        guard row >= 0, row < entries.count else { return }
        ClipboardMonitor.shared.remove(id: entries[row].id)
    }

    @objc private func clearAll() {
        ClipboardMonitor.shared.clearAll()
    }

    // MARK: - NSTableViewDataSource

    func numberOfRows(in tableView: NSTableView) -> Int { entries.count }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let entry = entries[row]
        let cell = ClipboardRowView(entry: entry, relativeFormatter: relTimeFormatter)
        return cell
    }

    func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {
        let r = ClipboardRow()
        return r
    }
}

extension ClipboardView: NSSearchFieldDelegate {
    func controlTextDidChange(_ obj: Notification) {
        filter = searchField.stringValue
        refresh()
    }
}

// MARK: - Row view

private final class ClipboardRow: NSTableRowView {
    override func drawSelection(in dirtyRect: NSRect) {
        if selectionHighlightStyle != .none {
            NSColor.white.withAlphaComponent(0.10).setFill()
            dirtyRect.fill()
        }
    }
}

private final class ClipboardRowView: NSTableCellView {
    init(entry: ClipboardEntry, relativeFormatter: RelativeDateTimeFormatter) {
        super.init(frame: .zero)

        let icon = NSTextField(labelWithString: iconFor(entry.kind))
        icon.textColor = .secondaryLabelColor
        icon.font = NSFont.systemFont(ofSize: 12)
        icon.widthAnchor.constraint(equalToConstant: 22).isActive = true

        let preview = NSTextField(labelWithString: entry.preview.isEmpty ? "(empty)" : entry.preview)
        preview.textColor = .white
        preview.font = NSFont.systemFont(ofSize: 12)
        preview.lineBreakMode = .byTruncatingTail
        preview.maximumNumberOfLines = 1
        preview.setContentHuggingPriority(.defaultLow, for: .horizontal)

        let when = NSTextField(labelWithString:
            relativeFormatter.localizedString(for: entry.createdAt, relativeTo: Date()))
        when.textColor = .secondaryLabelColor
        when.font = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .regular)

        let row = NSStackView(views: [icon, preview, when])
        row.orientation = .horizontal
        row.spacing = 8
        row.alignment = .centerY
        row.translatesAutoresizingMaskIntoConstraints = false
        addSubview(row)
        NSLayoutConstraint.activate([
            row.topAnchor.constraint(equalTo: topAnchor),
            row.bottomAnchor.constraint(equalTo: bottomAnchor),
            row.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            row.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    private func iconFor(_ kind: ClipboardEntry.Kind) -> String {
        switch kind {
        case .text:           return "≡"
        case .textTruncated:  return "≡…"
        case .image:          return "▢"
        case .imageTooLarge:  return "▢!"
        }
    }
}
