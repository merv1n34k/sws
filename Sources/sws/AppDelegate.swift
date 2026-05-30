import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private let hotkeyManager = HotkeyManager()
    private var window: ModeHostWindow?
    private var preferencesWindow: PreferencesWindow?
    private var config: SWSConfig!
    private var modes: [String: Mode] = [:]    // id → instance
    private var modeOrder: [String] = []       // preserves config order for menu

    func applicationDidFinishLaunching(_ notification: Notification) {
        registerBuiltInModes()
        config = SWSConfig.load()
        buildModes()
        setupMainMenu()
        setupStatusItem()
        setupWindow()
        registerDefaultHotkeyOnly()
        ensureScreenCapturePermission()
    }

    /// Color mode needs Screen Recording permission to read pixels
    /// from app windows; without it CGDisplayCreateImage falls back
    /// to the desktop wallpaper only. Prompt the user once on launch.
    private func ensureScreenCapturePermission() {
        guard config.modes.contains(where: { $0.type == "color" }) else { return }
        if CGPreflightScreenCaptureAccess() {
            NSLog("SWS: screen recording permission granted")
            return
        }
        NSLog("SWS: screen recording permission missing — prompting user")
        _ = CGRequestScreenCaptureAccess()
        // The prompt directs the user to System Settings > Privacy &
        // Security > Screen Recording. After enabling, sws must be
        // relaunched for the new permission to take effect.
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "SWS needs Screen Recording permission"
            alert.informativeText = """
                The color picker reads pixels from your screen. Without \
                Screen Recording permission it can only see the desktop \
                wallpaper, not app windows.

                Open System Settings → Privacy & Security → Screen \
                Recording, enable SWS, then quit and reopen SWS.
                """
            alert.addButton(withTitle: "Open System Settings")
            alert.addButton(withTitle: "Later")
            if alert.runModal() == .alertFirstButtonReturn {
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
                    NSWorkspace.shared.open(url)
                }
            }
        }
    }

    // MARK: - Mode lifecycle

    private func buildModes() {
        let prefs = AppPrefs(
            fontFamily: config.fontFamily,
            fontSize: config.fontSize,
            logInput: config.logInput
        )
        modes.removeAll()
        modeOrder.removeAll()
        for cfg in config.modes {
            let instance = cfg.toInstanceConfig()
            do {
                let mode = try ModeRegistry.shared.make(instance, appPrefs: prefs)
                modes[mode.id] = mode
                modeOrder.append(mode.id)
            } catch {
                NSLog("SWS: failed to build mode '\(cfg.id)' (type=\(cfg.type)): \(error)")
            }
        }
        if modes[config.defaultMode] == nil, let first = modeOrder.first {
            NSLog("SWS: defaultMode '\(config.defaultMode)' not found, falling back to '\(first)'")
            config.defaultMode = first
        }
    }

    private var defaultMode: Mode? { modes[config.defaultMode] }

    // MARK: - Window

    private func setupWindow() {
        let w = ModeHostWindow(width: config.width, height: config.height)
        w.onSizeChanged = { [weak self] width, height in
            guard let self = self, self.config.rememberSize else { return }
            self.config = self.config.withSize(width: width, height: height)
            self.config.save()
        }
        window = w
    }

    private func showWindow(mode: Mode) {
        guard let w = window else { return }
        w.show(mode: mode)
        registerAllModeHotkeys()
    }

    private func hideWindow() {
        window?.hide()
        registerDefaultHotkeyOnly()
    }

    private func switchTo(_ mode: Mode) {
        window?.switchMode(mode)
    }

    // MARK: - Hotkey routing

    private func registerDefaultHotkeyOnly() {
        hotkeyManager.unregisterAll()
        guard let cfg = config.mode(byID: config.defaultMode),
              let hk = cfg.hotkey else {
            NSLog("SWS: default mode '\(config.defaultMode)' has no hotkey")
            return
        }
        let ok = hotkeyManager.register(
            modeID: config.defaultMode,
            key: hk.key,
            modifiers: hk.modifiers
        ) { [weak self] in
            self?.handleDefaultHotkey()
        }
        if !ok {
            let fb = ShortcutConfig.default
            NSLog("SWS: falling back to default shortcut \(fb.key)+\(fb.modifiers)")
            hotkeyManager.register(
                modeID: config.defaultMode,
                key: fb.key,
                modifiers: fb.modifiers
            ) { [weak self] in
                self?.handleDefaultHotkey()
            }
        }
    }

    private func registerAllModeHotkeys() {
        for cfg in config.modes {
            guard cfg.id != config.defaultMode,
                  let hk = cfg.hotkey,
                  !hotkeyManager.isRegistered(modeID: cfg.id) else { continue }
            let id = cfg.id
            hotkeyManager.register(
                modeID: id,
                key: hk.key,
                modifiers: hk.modifiers
            ) { [weak self] in
                self?.handleModeHotkey(id)
            }
        }
    }

    private func handleDefaultHotkey() {
        guard let w = window, let def = defaultMode else { return }
        if !w.isVisible {
            showWindow(mode: def)
            return
        }
        if w.activeMode === def {
            hideWindow()
        } else {
            switchTo(def)
        }
    }

    private func handleModeHotkey(_ id: String) {
        guard let w = window,
              let target = modes[id],
              let def = defaultMode else { return }
        if w.activeMode === target {
            switchTo(def)
        } else {
            switchTo(target)
        }
    }

    // MARK: - Menus

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
        menu.addItem(NSMenuItem(title: "Show/Hide", action: #selector(toggleDefault), keyEquivalent: ""))

        // Mode submenu — populated from config order
        let modeItem = NSMenuItem(title: "Mode", action: nil, keyEquivalent: "")
        let modeSubmenu = NSMenu(title: "Mode")
        for id in modeOrder {
            guard let mode = modes[id] else { continue }
            let item = NSMenuItem(
                title: mode.displayName,
                action: #selector(switchModeFromMenu(_:)),
                keyEquivalent: ""
            )
            item.representedObject = id
            item.target = self
            modeSubmenu.addItem(item)
        }
        modeItem.submenu = modeSubmenu
        menu.addItem(modeItem)

        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Preferences...", action: #selector(openPreferences), keyEquivalent: ","))
        menu.addItem(NSMenuItem(title: "Reload Config", action: #selector(reloadConfig), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q"))
        statusItem.menu = menu
    }

    @objc private func toggleDefault() {
        handleDefaultHotkey()
    }

    @objc private func switchModeFromMenu(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? String,
              let mode = modes[id] else { return }
        if window?.isVisible != true {
            showWindow(mode: mode)
        } else {
            switchTo(mode)
        }
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
        config.save()
        buildModes()
        setupStatusItem()             // rebuilds mode submenu
        registerDefaultHotkeyOnly()
        if window?.isVisible == true {
            registerAllModeHotkeys()
        }
        NSLog("SWS: config applied")
    }

    @objc private func reloadConfig() {
        applyConfig(SWSConfig.load())
        NSLog("SWS: config reloaded")
    }

    @objc private func quitApp() {
        // Modes can clean up if needed; for now just terminate.
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
