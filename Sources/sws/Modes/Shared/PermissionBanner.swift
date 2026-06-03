import AppKit

/// Compact inline notice surfacing a missing TCC permission. Two rows
/// of text on the left, a "Open Settings…" button on the right that
/// opens the relevant Privacy & Security pane. Hidden by default —
/// call `update(visible:)` after probing the permission state.
final class PermissionBanner: NSView {
    private let icon = NSImageView()
    private let titleLabel = NSTextField(labelWithString: "")
    private let bodyLabel = NSTextField(labelWithString: "")
    private let actionButton = NSButton(title: "Open Settings…", target: nil, action: nil)
    private var settingsURL: URL?

    init() {
        super.init(frame: .zero)
        wantsLayer = true
        layer?.cornerRadius = 8
        layer?.backgroundColor = NSColor.systemYellow.withAlphaComponent(0.18).cgColor
        layer?.borderWidth = 1
        layer?.borderColor = NSColor.systemYellow.withAlphaComponent(0.5).cgColor

        icon.image = NSImage(systemSymbolName: "lock.shield", accessibilityDescription: "Permission")
        icon.contentTintColor = .systemYellow
        icon.translatesAutoresizingMaskIntoConstraints = false

        titleLabel.font = NSFont.systemFont(ofSize: 12, weight: .semibold)
        titleLabel.textColor = .white
        titleLabel.maximumNumberOfLines = 1

        bodyLabel.font = NSFont.systemFont(ofSize: 11)
        bodyLabel.textColor = NSColor.white.withAlphaComponent(0.85)
        bodyLabel.maximumNumberOfLines = 3
        bodyLabel.lineBreakMode = .byWordWrapping

        actionButton.bezelStyle = .rounded
        actionButton.controlSize = .small
        actionButton.target = self
        actionButton.action = #selector(openSettings)

        let text = NSStackView(views: [titleLabel, bodyLabel])
        text.orientation = .vertical
        text.alignment = .leading
        text.spacing = 2
        text.translatesAutoresizingMaskIntoConstraints = false

        addSubview(icon)
        addSubview(text)
        addSubview(actionButton)
        actionButton.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            icon.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            icon.centerYAnchor.constraint(equalTo: centerYAnchor),
            icon.widthAnchor.constraint(equalToConstant: 18),
            icon.heightAnchor.constraint(equalToConstant: 18),

            text.leadingAnchor.constraint(equalTo: icon.trailingAnchor, constant: 10),
            text.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            text.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8),
            text.trailingAnchor.constraint(lessThanOrEqualTo: actionButton.leadingAnchor, constant: -8),

            actionButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
            actionButton.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
        isHidden = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    /// `settingsURL` should point at the Privacy pane the user needs
    /// to grant in (e.g. `x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture`).
    func configure(title: String, body: String, settingsURL: URL) {
        self.titleLabel.stringValue = title
        self.bodyLabel.stringValue = body
        self.settingsURL = settingsURL
    }

    func setVisible(_ visible: Bool) {
        isHidden = !visible
    }

    @objc private func openSettings() {
        if let url = settingsURL {
            NSWorkspace.shared.open(url)
        }
    }
}

// MARK: - Permission probes

enum SystemPermission {
    /// True if Screen Recording is granted. macOS may show its own
    /// prompt on first call; the result reflects the *current* grant.
    static func screenRecordingGranted() -> Bool {
        CGPreflightScreenCaptureAccess()
    }

    /// Heuristic for Full Disk Access — tries to read a path that
    /// requires FDA. Returns true if reachable. There is no public
    /// API for this on macOS, hence the probe approach.
    static func fullDiskAccessGranted() -> Bool {
        let probe = "/Library/Application Support/com.apple.TCC/TCC.db"
        return FileManager.default.isReadableFile(atPath: probe)
    }

    static let screenRecordingSettingsURL = URL(
        string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture"
    )!

    static let fullDiskAccessSettingsURL = URL(
        string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles"
    )!
}
