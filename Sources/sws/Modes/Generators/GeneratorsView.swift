import AppKit

final class GeneratorsView: NSView {
    private enum Section: Int, CaseIterable {
        case password, uuid, lorem, random
        var title: String {
            switch self {
            case .password: return "Password"
            case .uuid: return "UUID"
            case .lorem: return "Lorem"
            case .random: return "Random"
            }
        }
    }

    private let segmented: NSSegmentedControl
    private let container: NSView

    private let passwordSection = PasswordSection()
    private let uuidSection = UUIDSection()
    private let loremSection = LoremSection()
    private let randomSection = RandomSection()

    init() {
        segmented = NSSegmentedControl(
            labels: Section.allCases.map(\.title),
            trackingMode: .selectOne,
            target: nil,
            action: nil
        )
        container = NSView()
        super.init(frame: .zero)

        wantsLayer = true
        layer?.backgroundColor = NSColor(white: 0.1, alpha: 1).cgColor

        segmented.target = self
        segmented.action = #selector(sectionChanged(_:))
        segmented.segmentStyle = .texturedRounded
        segmented.translatesAutoresizingMaskIntoConstraints = false
        segmented.selectedSegment = 0
        addSubview(segmented)

        container.translatesAutoresizingMaskIntoConstraints = false
        addSubview(container)

        NSLayoutConstraint.activate([
            segmented.topAnchor.constraint(equalTo: topAnchor, constant: 10),
            segmented.centerXAnchor.constraint(equalTo: centerXAnchor),
            container.topAnchor.constraint(equalTo: segmented.bottomAnchor, constant: 10),
            container.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            container.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
            container.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -14),
        ])

        installSection(.password)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    @objc private func sectionChanged(_ sender: NSSegmentedControl) {
        if let section = Section(rawValue: sender.selectedSegment) {
            installSection(section)
        }
    }

    private func installSection(_ section: Section) {
        for sub in container.subviews { sub.removeFromSuperview() }
        let view: NSView
        switch section {
        case .password: view = passwordSection
        case .uuid:     view = uuidSection
        case .lorem:    view = loremSection
        case .random:   view = randomSection
        }
        view.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(view)
        NSLayoutConstraint.activate([
            view.topAnchor.constraint(equalTo: container.topAnchor),
            view.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            view.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            view.trailingAnchor.constraint(equalTo: container.trailingAnchor),
        ])
        (view as? GeneratorsSection)?.refresh()
    }
}

protocol GeneratorsSection: NSView {
    func refresh()
}
