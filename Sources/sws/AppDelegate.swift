import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var hotkeyManager = HotkeyManager()
    private var terminalWindow: TerminalWindow?
    private var preferencesWindow: PreferencesWindow?
    private var config: SWSConfig!

    func applicationDidFinishLaunching(_ notification: Notification) {
        config = SWSConfig.load()
        setupMainMenu()
        setupStatusItem()
        setupHotkey()
        setupWindow()
    }

    private func setupMainMenu() {
        let mainMenu = NSMenu()

        let appMenu = NSMenu()
        appMenu.addItem(NSMenuItem(title: "Quit SWS", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        let appItem = NSMenuItem()
        appItem.submenu = appMenu
        mainMenu.addItem(appItem)

        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(NSMenuItem(title: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c"))
        editMenu.addItem(NSMenuItem(title: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v"))
        editMenu.addItem(NSMenuItem(title: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a"))
        let editItem = NSMenuItem()
        editItem.submenu = editMenu
        mainMenu.addItem(editItem)

        NSApp.mainMenu = mainMenu
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "terminal", accessibilityDescription: "SWS")
                ?? makeTextImage(">_")
        }

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Show/Hide", action: #selector(toggleWindow), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Preferences...", action: #selector(openPreferences), keyEquivalent: ","))
        menu.addItem(NSMenuItem(title: "Reload Config", action: #selector(reloadConfig), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q"))
        statusItem.menu = menu
    }

    private func setupHotkey() {
        hotkeyManager.register(
            key: config.shortcut.key,
            modifiers: config.shortcut.modifiers
        ) { [weak self] in
            self?.terminalWindow?.toggle()
        }
    }

    private func setupWindow() {
        let window = TerminalWindow(config: config)
        window.onSizeChanged = { [weak self] width, height in
            guard let self = self, self.config.rememberSize else { return }
            self.config = self.config.withSize(width: width, height: height)
            self.config.save()
        }
        window.terminalView.onProcessExit = { [weak self] in
            // Restart process after a brief delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self?.terminalWindow?.terminalView.startProcess()
            }
        }
        terminalWindow = window
    }

    @objc private func toggleWindow() {
        terminalWindow?.toggle()
    }

    @objc private func openPreferences() {
        let prefs = PreferencesWindow(config: config)
        prefs.onConfigChanged = { [weak self] newConfig in
            self?.applyConfig(newConfig)
        }
        prefs.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        preferencesWindow = prefs
    }

    private func applyConfig(_ newConfig: SWSConfig) {
        config = newConfig
        terminalWindow?.reloadConfig(config)
        setupHotkey()
        NSLog("SWS: config applied")
    }

    @objc private func reloadConfig() {
        config = SWSConfig.load()
        terminalWindow?.reloadConfig(config)
        setupHotkey()
        NSLog("SWS: config reloaded")
    }

    @objc private func quitApp() {
        terminalWindow?.terminalView.stopProcess()
        NSApp.terminate(nil)
    }

    private func makeTextImage(_ text: String) -> NSImage {
        let img = NSImage(size: NSSize(width: 18, height: 18))
        img.lockFocus()
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: 12, weight: .bold),
            .foregroundColor: NSColor.black,
        ]
        (text as NSString).draw(at: NSPoint(x: 1, y: 2), withAttributes: attrs)
        img.unlockFocus()
        img.isTemplate = true
        return img
    }
}
