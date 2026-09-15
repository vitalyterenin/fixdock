import AppKit
import CoreGraphics
import ServiceManagement

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
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

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        dockEdge = dockPreferences.currentEdge
        currentDockDisplayID = dockSystemController.currentDockDisplayID(displays: displayManager.displays)
        selectedDisplayID = settingsStore.targetDisplayID ?? currentDockDisplayID ?? displayManager.normalizedTargetDisplayID(preferredID: nil)
        settingsStore.targetDisplayID = selectedDisplayID
        setupStatusItem()
        installObservers()
        updateProtection()
        startTimer()
    }

    func applicationWillTerminate(_ notification: Notification) {
        updateTimer?.invalidate()
        mouseEdgeGuard.stop()
        dockSystemController.setDisplaySwitchingAllowed(true)
    }

    @objc private func selectDisplay(_ sender: NSMenuItem) {
        guard let number = sender.representedObject as? NSNumber else {
            return
        }

        selectedDisplayID = CGDirectDisplayID(number.uint32Value)
        settingsStore.targetDisplayID = selectedDisplayID
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
    }

    @objc private func screenParametersDidChange() {
        normalizeSelectedDisplay()
        updateProtection()
    }

    private func startTimer() {
        updateTimer = Timer.scheduledTimer(
            timeInterval: 1.0,
            target: self,
            selector: #selector(refreshStateFromTimer),
            userInfo: nil,
            repeats: true
        )
    }

    private func normalizeSelectedDisplay() {
        let normalized = displayManager.normalizedTargetDisplayID(preferredID: selectedDisplayID)
        if normalized != selectedDisplayID {
            selectedDisplayID = normalized
            settingsStore.targetDisplayID = normalized
        }
    }

    private func updateProtection() {
        let displays = displayManager.displays
        currentDockDisplayID = dockSystemController.currentDockDisplayID(displays: displays)
        mouseEdgeGuard.update(displays: displays, targetDisplayID: selectedDisplayID, dockEdge: dockEdge)

        guard let selectedDisplayID else {
            lastStatusMessage = "No display selected"
            refreshMenu()
            return
        }

        if currentDockDisplayID == selectedDisplayID {
            if dockSystemController.isDisplaySwitchingAllowed {
                dockSystemController.setDisplaySwitchingAllowed(false)
            }
        } else {
            if !dockSystemController.isDisplaySwitchingAllowed {
                dockSystemController.setDisplaySwitchingAllowed(true)
            }
        }

        let canFilterEdgeGestures = mouseEdgeGuard.isRunning || mouseEdgeGuard.start()
        if currentDockDisplayID == selectedDisplayID {
            lastStatusMessage = if canFilterEdgeGestures {
                "Dock locked to \(displayName(for: selectedDisplayID))"
            } else {
                "Dock locked; Accessibility required"
            }
        } else if currentDockDisplayID == nil {
            lastStatusMessage = if canFilterEdgeGestures {
                "Dock not detected; switching enabled"
            } else {
                "Accessibility required; switching enabled"
            }
        } else {
            lastStatusMessage = if canFilterEdgeGestures {
                "Move the pointer to the edge of \(displayName(for: selectedDisplayID))"
            } else {
                "Switching enabled; Accessibility required"
            }
        }

        refreshMenu()
    }

    private func refreshMenu() {
        let menu = NSMenu()

        let titleItem = NSMenuItem(title: "Fixdock", action: nil, keyEquivalent: "")
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

        let quitItem = NSMenuItem(title: "Quit Fixdock", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quitItem)

        statusItem?.menu = menu
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
