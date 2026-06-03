import AppKit

/// Watches for external volumes (removable + non-internal mounts) and
/// spawns a per-volume widget into the menu bar. Widgets disappear
/// automatically when the volume is ejected.
///
/// This monitor is strictly scoped to storage — there's no general
/// "auto-spawn" extension point. Volumes come from
/// `mountedVolumeURLs` + `NSWorkspace.didMount/didUnmount`, and each
/// one drives exactly one `ExternalVolumeWidget`.
final class ExternalStorageMonitor {
    static let shared = ExternalStorageMonitor()

    private var widgets: [URL: ExternalVolumeWidget] = [:]
    private var started = false

    func start() {
        guard !started else { return }
        started = true
        let nc = NSWorkspace.shared.notificationCenter
        nc.addObserver(self, selector: #selector(volumesChanged(_:)),
                       name: NSWorkspace.didMountNotification, object: nil)
        nc.addObserver(self, selector: #selector(volumesChanged(_:)),
                       name: NSWorkspace.didUnmountNotification, object: nil)
        rescan()
    }

    @objc private func volumesChanged(_: Notification) {
        rescan()
    }

    private func rescan() {
        let keys: Set<URLResourceKey> = [
            .volumeIsInternalKey,
            .volumeIsRemovableKey,
            .volumeIsLocalKey,
            .volumeLocalizedNameKey,
            .volumeUUIDStringKey,
        ]
        let mounted = FileManager.default.mountedVolumeURLs(
            includingResourceValuesForKeys: Array(keys),
            options: [.skipHiddenVolumes]
        ) ?? []

        var seen: Set<URL> = []
        for url in mounted {
            guard let values = try? url.resourceValues(forKeys: keys) else { continue }
            // Treat as external when explicitly removable OR the
            // kernel flags the volume as non-internal. Skip network
            // mounts that aren't local (we don't want every SMB share
            // to clutter the menu bar).
            let removable = values.volumeIsRemovable ?? false
            let internalVol = values.volumeIsInternal ?? true
            let isLocal = values.volumeIsLocal ?? true
            guard isLocal, (removable || !internalVol) else { continue }

            seen.insert(url)
            if widgets[url] == nil {
                let name = values.volumeLocalizedName ?? url.lastPathComponent
                let widget = ExternalVolumeWidget(volumeURL: url, name: name)
                widgets[url] = widget
                MenuBarWidgetRegistry.shared.spawnVolumeWidget(widget)
            }
        }
        // Drop widgets for volumes that vanished.
        for (url, widget) in widgets where !seen.contains(url) {
            MenuBarWidgetRegistry.shared.removeVolumeWidget(id: widget.id)
            widgets.removeValue(forKey: url)
        }
    }
}

/// Menu-bar widget representing one external volume. Shows the volume
/// name on the top row and free space on the bottom row, mirroring the
/// existing SSD widget's layout so the bar reads consistently.
final class ExternalVolumeWidget: MenuBarWidget {
    let id: String
    let detailTitle: String
    let pollInterval: TimeInterval = 30
    private let volumeURL: URL
    private let name: String
    private var lastBreakdown: VolumeBreakdown?
    private weak var detail: ExternalVolumeDetailView?
    private let reserved: CGFloat

    init(volumeURL: URL, name: String) {
        // Reserved width handles the volume's actual display name plus
        // a "999 GB" worst-case bottom row.
        let topFont = NSFont.systemFont(ofSize: 8, weight: .semibold)
        let bottomFont = NSFont.monospacedDigitSystemFont(ofSize: 9, weight: .medium)
        let topW = (name as NSString).size(withAttributes: [.font: topFont]).width
        let bottomW = ("999 GB" as NSString).size(withAttributes: [.font: bottomFont]).width
        self.reserved = ceil(max(topW, bottomW)) + 4
        self.volumeURL = volumeURL
        self.name = name
        self.id = "external:\(volumeURL.path)"
        self.detailTitle = name
    }

    func render() -> MenuBarRendering {
        let m = readBreakdown()
        lastBreakdown = m
        detail?.update(m: m, name: name, volumeURL: volumeURL)
        return .twoLines(
            top: name,
            bottom: SystemStats.humanBytesShort(m.free),
            minWidth: reserved
        )
    }

    func currentValue() -> String {
        guard let m = lastBreakdown else { return "—" }
        return "\(SystemStats.humanBytes(m.free)) free"
    }

    func detailView() -> NSView? {
        let v = ExternalVolumeDetailView()
        v.update(m: lastBreakdown ?? readBreakdown(), name: name, volumeURL: volumeURL)
        detail = v
        return v
    }

    // MARK: - Per-volume capacity readout

    struct VolumeBreakdown {
        var total: Int64
        var free: Int64
        var used: Int64
        var usedFraction: Double {
            total > 0 ? Double(used) / Double(total) : 0
        }
    }

    private func readBreakdown() -> VolumeBreakdown {
        let keys: Set<URLResourceKey> = [
            .volumeAvailableCapacityKey,
            .volumeTotalCapacityKey,
        ]
        guard let values = try? volumeURL.resourceValues(forKeys: keys) else {
            return VolumeBreakdown(total: 0, free: 0, used: 0)
        }
        let total = Int64(values.volumeTotalCapacity ?? 0)
        let free = Int64(values.volumeAvailableCapacity ?? 0)
        return VolumeBreakdown(total: total, free: free, used: max(0, total - free))
    }
}

private final class ExternalVolumeDetailView: NSView {
    private let freeLabel = NSTextField(labelWithString: "— free")
    private let totalLabel = NSTextField(labelWithString: "")
    private let bar = CapacityBar()
    private let pathLabel = NSTextField(labelWithString: "")
    private let ejectButton = NSButton(title: "Eject", target: nil, action: nil)
    private var volumeURL: URL?

    private var usedRow: (row: NSView, value: NSTextField)!
    private var freeRow: (row: NSView, value: NSTextField)!

    init() {
        super.init(frame: .zero)
        freeLabel.font = NSFont.systemFont(ofSize: 18, weight: .semibold)
        totalLabel.font = NSFont.systemFont(ofSize: 11)
        totalLabel.textColor = .secondaryLabelColor
        pathLabel.font = NSFont.systemFont(ofSize: 10)
        pathLabel.textColor = .tertiaryLabelColor

        bar.translatesAutoresizingMaskIntoConstraints = false
        bar.thresholds = (yellow: 0.85, red: 0.95)

        usedRow = WidgetPopover.labeledRow("Used", value: "—")
        freeRow = WidgetPopover.labeledRow("Free", value: "—")

        ejectButton.bezelStyle = .accessoryBarAction
        ejectButton.controlSize = .small
        ejectButton.target = self
        ejectButton.action = #selector(eject)

        let headline = NSStackView(views: [freeLabel, NSView(), totalLabel])
        headline.orientation = .horizontal
        headline.alignment = .firstBaseline

        let breakdown = NSStackView(views: [usedRow.row, freeRow.row])
        breakdown.orientation = .vertical
        breakdown.alignment = .leading
        breakdown.spacing = 2

        let stack = NSStackView(views: [headline, bar, breakdown, pathLabel, ejectButton])
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
            bar.widthAnchor.constraint(greaterThanOrEqualToConstant: 240),
            usedRow.row.widthAnchor.constraint(equalTo: stack.widthAnchor),
            freeRow.row.widthAnchor.constraint(equalTo: stack.widthAnchor),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    func update(m: ExternalVolumeWidget.VolumeBreakdown, name: String, volumeURL: URL) {
        self.volumeURL = volumeURL
        freeLabel.stringValue = "\(SystemStats.humanBytes(m.free)) free"
        totalLabel.stringValue = "of \(SystemStats.humanBytes(m.total))"
        bar.fill = m.usedFraction
        usedRow.value.stringValue = SystemStats.humanBytes(m.used)
        freeRow.value.stringValue = SystemStats.humanBytes(m.free)
        pathLabel.stringValue = volumeURL.path
    }

    @objc private func eject() {
        guard let url = volumeURL else { return }
        do {
            try NSWorkspace.shared.unmountAndEjectDevice(at: url)
        } catch {
            NSLog("SWS: failed to eject \(url.path): \(error)")
        }
    }
}
