import AppKit
import CoreGraphics
import ServiceManagement

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let updates = UpdateController()
    private let settingsStore = SettingsStore()
    private let displayManager = DisplayManager()
    private let dockPreferences = DockPreferences()
    private let dockSystemController = DockSystemController()
    private let mouseEdgeGuard = MouseEdgeGuard()

    private var statusItem: NSStatusItem?
    private var updateTimer: Timer?
    private var selectedDisplayID: CGDirectDisplayID?
    private var currentDockDisplayID: CGDirectDisplayID?
    private var dockEdge: DockEdge = .bottom
    private var lastStatusMessage = ""
    private var dockVisibilitySnapshot: DockVisibilitySnapshot?
    private var lockPolicy = DockLockPolicy()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        let snapshot = settingsStore.dockVisibilitySnapshot ?? DockVisibilitySnapshot(
            isAutoHideEnabled: dockSystemController.isAutoHideEnabled,
            autoHideLockValue: dockSystemController.autoHideLockValue
        )
        settingsStore.dockVisibilitySnapshot = snapshot
        dockVisibilitySnapshot = snapshot
        dockEdge = dockPreferences.currentEdge
        currentDockDisplayID = dockSystemController.currentDockDisplayID(displays: displayManager.displays)
        selectedDisplayID = settingsStore.targetDisplayID ?? currentDockDisplayID ?? displayManager.normalizedTargetDisplayID(preferredID: nil)
        settingsStore.targetDisplayID = selectedDisplayID
        updates.start()
        setupStatusItem()
        installObservers()
        updateProtection()
        startTimer()
    }

    func applicationWillTerminate(_ notification: Notification) {
        updateTimer?.invalidate()
        DistributedNotificationCenter.default().removeObserver(self)
        NSWorkspace.shared.notificationCenter.removeObserver(self)
        mouseEdgeGuard.stop()
        dockSystemController.setDisplaySwitchingAllowed(true)
        if let dockVisibilitySnapshot {
            let needsDockReload = dockSystemController.autoHideLockValue != dockVisibilitySnapshot.autoHideLockValue ||
                dockSystemController.isAutoHideEnabled != dockVisibilitySnapshot.isAutoHideEnabled
            if needsDockReload {
                dockSystemController.setAutoHideLockValue(dockVisibilitySnapshot.autoHideLockValue)
                dockSystemController.setAutoHideEnabled(dockVisibilitySnapshot.isAutoHideEnabled)
                dockSystemController.reloadDock()
            }
            settingsStore.dockVisibilitySnapshot = nil
        }
    }

    @objc private func selectDisplay(_ sender: NSMenuItem) {
        guard let number = sender.representedObject as? NSNumber else {
            return
        }

        selectedDisplayID = CGDirectDisplayID(number.uint32Value)
        settingsStore.targetDisplayID = selectedDisplayID
        lockPolicy.requestTransfer(to: CGDirectDisplayID(number.uint32Value))
        updateProtection()
    }

    @objc private func refreshStateFromTimer() {
        dockEdge = dockPreferences.currentEdge
        normalizeSelectedDisplay()
        updateProtection()
    }

    @objc private func openAccessibilitySettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") else {
            return
        }

        NSWorkspace.shared.open(url)
    }

    @objc private func toggleLaunchAtLogin() {
        let service = SMAppService.mainApp

        do {
            if service.status == .enabled {
                try service.unregister()
            } else if service.status == .requiresApproval {
                openLoginItemsSettings()
            } else {
                try service.register()
            }
        } catch {
            NSSound.beep()
        }

        refreshMenu()
    }

    private func openLoginItemsSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.LoginItems-Settings.extension") else {
            return
        }

        NSWorkspace.shared.open(url)
    }

    private func setupStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let image = NSImage(systemSymbolName: "dock.rectangle", accessibilityDescription: "Fixdock") {
            item.button?.image = image
            item.button?.imagePosition = .imageOnly
        } else {
            item.button?.title = "FD"
        }
        statusItem = item
        refreshMenu()
    }

    private func installObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenParametersDidChange),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(dockPreferencesDidChange),
            name: Notification.Name("com.apple.dock.prefchanged"),
            object: nil
        )
        for name in [NSWorkspace.activeSpaceDidChangeNotification,
                     NSWorkspace.didWakeNotification,
                     NSWorkspace.didLaunchApplicationNotification,
                     NSWorkspace.didTerminateApplicationNotification] {
            NSWorkspace.shared.notificationCenter.addObserver(
                self, selector: #selector(refreshStateFromTimer), name: name, object: nil
            )
        }
    }

    @objc private func dockPreferencesDidChange() {
        updateProtection()
    }

    @objc private func screenParametersDidChange() {
        normalizeSelectedDisplay()
        updateProtection()
    }

    private func startTimer() {
        updateTimer = Timer.scheduledTimer(
            timeInterval: 0.25,
            target: self,
            selector: #selector(refreshStateFromTimer),
            userInfo: nil,
            repeats: true
        )
        if let updateTimer {
            RunLoop.main.add(updateTimer, forMode: .common)
        }
    }

    private func normalizeSelectedDisplay() {
        // Screen/Space transitions must not replace the user's saved selection.
        if selectedDisplayID == nil {
            selectedDisplayID = displayManager.normalizedTargetDisplayID(preferredID: nil)
            settingsStore.targetDisplayID = selectedDisplayID
        }
    }

    private func updateProtection() {
        let displays = displayManager.displays
        currentDockDisplayID = dockSystemController.currentDockDisplayID(displays: displays)
        mouseEdgeGuard.update(displays: displays, targetDisplayID: selectedDisplayID, dockEdge: dockEdge)
        let canFilterEdgeGestures = mouseEdgeGuard.start()
        let allowSwitching = lockPolicy.allowsSwitching(
            selectedDisplayID: selectedDisplayID,
            currentDisplayID: currentDockDisplayID,
            availableDisplayIDs: Set(displays.map(\.id)),
            edgeGuardRunning: canFilterEdgeGestures
        )
        if dockSystemController.isDisplaySwitchingAllowed != allowSwitching {
            dockSystemController.setDisplaySwitchingAllowed(allowSwitching)
        }
        // Apply the lock before any visibility correction can restart Dock.
        enforceDockVisibility()

        guard let selectedDisplayID else {
            lastStatusMessage = "No display selected"
            refreshMenu()
            return
        }

        if !displays.contains(where: { $0.id == selectedDisplayID }) {
            lastStatusMessage = "Selected display unavailable; switching blocked"
        } else if currentDockDisplayID == selectedDisplayID {
            lastStatusMessage = if canFilterEdgeGestures {
                "Dock locked to \(displayName(for: selectedDisplayID))"
            } else {
                "Dock locked; Accessibility required"
            }
        } else if currentDockDisplayID == nil {
            lastStatusMessage = if canFilterEdgeGestures {
                "Dock not detected; switching blocked"
            } else {
                "Dock not detected; Accessibility required; switching blocked"
            }
        } else if allowSwitching {
            lastStatusMessage = if canFilterEdgeGestures {
                "Move the pointer to the edge of \(displayName(for: selectedDisplayID))"
            } else {
                "Accessibility required; switching blocked"
            }
        } else {
            lastStatusMessage = "Dock on another display; switching blocked; reselect target to move"
        }

        refreshMenu()
    }

    private func enforceDockVisibility() {
        var needsDockReload = false
        if dockSystemController.isAutoHideEnabled {
            dockSystemController.setAutoHideEnabled(false)
            needsDockReload = true
        }
        if dockSystemController.autoHideLockValue != true {
            dockSystemController.setAutoHideLockValue(true)
            needsDockReload = true
        }
        if needsDockReload {
            dockSystemController.reloadDock()
        }
    }

    private func refreshMenu() {
        let menu = NSMenu()

        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Development"
        let titleItem = NSMenuItem(title: "Fixdock \(version)", action: nil, keyEquivalent: "")
        titleItem.isEnabled = false
        menu.addItem(titleItem)

        let stateItem = NSMenuItem(title: lastStatusMessage.isEmpty ? "Dock locked" : lastStatusMessage, action: nil, keyEquivalent: "")
        stateItem.isEnabled = false
        menu.addItem(stateItem)

        if !mouseEdgeGuard.isAccessibilityTrusted {
            let accessibilityItem = NSMenuItem(
                title: "Open Accessibility Settings",
                action: #selector(openAccessibilitySettings),
                keyEquivalent: ""
            )
            accessibilityItem.target = self
            menu.addItem(accessibilityItem)
        }

        menu.addItem(.separator())

        let displayHeaderItem = NSMenuItem(title: "Dock Display", action: nil, keyEquivalent: "")
        displayHeaderItem.isEnabled = false
        menu.addItem(displayHeaderItem)
        addDisplayItems(to: menu)

        menu.addItem(.separator())

        let launchAtLoginService = SMAppService.mainApp
        let launchAtLoginTitle = launchAtLoginService.status == .requiresApproval
            ? "Launch at Login (Approval Required)"
            : "Launch at Login"
        let launchAtLoginItem = NSMenuItem(
            title: launchAtLoginTitle,
            action: #selector(toggleLaunchAtLogin),
            keyEquivalent: ""
        )
        launchAtLoginItem.target = self
        launchAtLoginItem.state = launchAtLoginService.status == .enabled ? .on : .off
        menu.addItem(launchAtLoginItem)

        menu.addItem(.separator())

        let updateMenu = NSMenu()
        let checkItem = NSMenuItem(title: "Check for Updates…", action: #selector(checkForUpdates(_:)), keyEquivalent: "")
        checkItem.target = self
        checkItem.isEnabled = updates.canCheck
        updateMenu.addItem(checkItem)
        for (title, action, enabled) in [
            ("Automatically Check for Updates", #selector(toggleAutomaticChecks(_:)), updates.automaticallyChecks),
            ("Automatically Install Updates", #selector(toggleAutomaticInstallation(_:)), updates.automaticallyInstalls)
        ] {
            let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
            item.target = self
            item.state = enabled ? .on : .off
            item.isEnabled = updates.isConfigured
            updateMenu.addItem(item)
        }
        let updateItem = NSMenuItem(title: "Updates", action: nil, keyEquivalent: "")
        updateItem.submenu = updateMenu
        menu.addItem(updateItem)
        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "Quit Fixdock", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quitItem)

        statusItem?.menu = menu
    }

    @objc private func checkForUpdates(_ sender: Any?) { updates.check(sender) }
    @objc private func toggleAutomaticChecks(_ sender: Any?) {
        updates.setAutomaticChecks(!updates.automaticallyChecks)
        refreshMenu()
    }
    @objc private func toggleAutomaticInstallation(_ sender: Any?) {
        updates.setAutomaticInstallation(!updates.automaticallyInstalls)
        refreshMenu()
    }

    // Build validation constructs the real menu without starting protection,
    // modifying Dock preferences, requesting access, or checking the network.
    func smokeTestMenu() -> Bool {
        setupStatusItem()
        guard let menu = statusItem?.menu,
              menu.items.contains(where: { $0.title == "Dock Display" }),
              let submenu = menu.items.first(where: { $0.title == "Updates" })?.submenu,
              submenu.items.count == 3 else { return false }
        return true
    }

    private func addDisplayItems(to menu: NSMenu) {
        for display in displayManager.displays {
            let item = NSMenuItem(title: display.displayName, action: #selector(selectDisplay(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = NSNumber(value: display.id)
            item.state = display.id == selectedDisplayID ? .on : .off
            menu.addItem(item)
        }
    }

    private func displayName(for displayID: CGDirectDisplayID?) -> String {
        guard let displayID else {
            return "Unknown display"
        }

        return displayManager.displays.first(where: { $0.id == displayID })?.name ?? "Unknown display"
    }
}
