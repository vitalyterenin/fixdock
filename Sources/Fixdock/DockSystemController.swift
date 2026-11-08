import AppKit
import CoreGraphics
import Darwin
import Foundation

final class DockSystemController {
    private let dockDomain = "com.apple.dock"
    private let allowDisplaySwitchingKey = "allow-display-switching"
    private let autoHideKey = "autohide"
    private let autoHideLockKey = "autohide-immutable"
    private let dockPreferencesChangedNotification = Notification.Name("com.apple.dock.prefchanged")
    private lazy var skyLightDockRectReader = SkyLightDockRectReader()

    var isDisplaySwitchingAllowed: Bool {
        booleanPreference(allowDisplaySwitchingKey) ?? true
    }

    var isAutoHideEnabled: Bool {
        booleanPreference(autoHideKey) ?? false
    }

    var autoHideLockValue: Bool? {
        booleanPreference(autoHideLockKey)
    }

    private func booleanPreference(_ key: String) -> Bool? {
        // Read external changes without spawning a process on the event-tap run loop.
        CFPreferencesAppSynchronize(dockDomain as CFString)
        return (CFPreferencesCopyAppValue(key as CFString, dockDomain as CFString) as? NSNumber)?.boolValue
    }

    func setAutoHideLockValue(_ value: Bool?) {
        let arguments: [String]
        if let value {
            arguments = ["write", dockDomain, autoHideLockKey, "-bool", value ? "true" : "false"]
        } else {
            arguments = ["delete", dockDomain, autoHideLockKey]
        }

        _ = runDefaults(arguments: arguments)
        DistributedNotificationCenter.default().postNotificationName(
            dockPreferencesChangedNotification,
            object: nil
        )
    }

    func reloadDock() {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/killall")
        process.arguments = ["Dock"]
        process.standardOutput = Pipe()
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            // The next Dock launch will read the updated preferences.
        }
    }

    func setAutoHideEnabled(_ enabled: Bool) {
        _ = runDefaults(arguments: [
            "write",
            dockDomain,
            autoHideKey,
            "-bool",
            enabled ? "true" : "false"
        ])
        DistributedNotificationCenter.default().postNotificationName(
            dockPreferencesChangedNotification,
            object: nil
        )
    }

    func setDisplaySwitchingAllowed(_ allowed: Bool) {
        _ = runDefaults(arguments: [
            "write",
            dockDomain,
            allowDisplaySwitchingKey,
            "-bool",
            allowed ? "true" : "false"
        ])
        DistributedNotificationCenter.default().postNotificationName(
            dockPreferencesChangedNotification,
            object: nil
        )
    }

    func currentDockDisplayID(displays: [DisplayInfo]) -> CGDirectDisplayID? {
        if let dockFrame = currentDockWindowFrame() {
            return bestMatchingDisplayID(for: dockFrame, displays: displays)
        }

        if let dockFrame = skyLightDockRectReader?.currentDockRect() {
            return bestMatchingDisplayID(for: dockFrame, displays: displays)
        }

        return nil
    }

    private func currentDockWindowFrame() -> CGRect? {
        let windowList = CGWindowListCopyWindowInfo([.optionAll], kCGNullWindowID) as? [[String: Any]]
        guard let windowList else {
            return nil
        }

        let dockWindow = windowList.first { window in
            guard
                let owner = window[kCGWindowOwnerName as String] as? String,
                let name = window[kCGWindowName as String] as? String,
                let layer = window[kCGWindowLayer as String] as? Int
            else {
                return false
            }

            return owner == "Dock" && name == "Dock" && layer == 20
        }

        guard
            let dockWindow,
            let bounds = dockWindow[kCGWindowBounds as String] as? [String: Any],
            let dockFrame = CGRect(dictionaryRepresentation: bounds as CFDictionary)
        else {
            return nil
        }

        return dockFrame
    }

    private func bestMatchingDisplayID(for dockFrame: CGRect, displays: [DisplayInfo]) -> CGDirectDisplayID? {
        let bestMatch = displays
            .map { display in
                (id: display.id, area: dockFrame.intersection(display.quartzFrame).area)
            }
            .max { lhs, rhs in lhs.area < rhs.area }

        guard let bestMatch, bestMatch.area > 0 else {
            return nil
        }

        return bestMatch.id
    }

    private func runDefaults(arguments: [String]) -> (exitCode: Int32, output: String) {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/defaults")
        process.arguments = arguments
        process.standardOutput = pipe
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            return (process.terminationStatus, String(data: data, encoding: .utf8) ?? "")
        } catch {
            return (1, "")
        }
    }
}

private final class SkyLightDockRectReader {
    private typealias SLSMainConnectionIDFunction = @convention(c) () -> Int32
    private typealias SLSGetDockRectWithOrientationFunction = @convention(c) (
        Int32,
        UnsafeMutablePointer<CGRect>,
        UnsafeMutablePointer<Int32>,
        UnsafeMutablePointer<Int32>
    ) -> Int32

    private let handle: UnsafeMutableRawPointer
    private let slsMainConnectionID: SLSMainConnectionIDFunction
    private let slsGetDockRectWithOrientation: SLSGetDockRectWithOrientationFunction

    init?() {
        let path = "/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight"
        guard let handle = dlopen(path, RTLD_LAZY | RTLD_LOCAL) else {
            return nil
        }

        guard
            let mainConnectionIDSymbol = dlsym(handle, "SLSMainConnectionID"),
            let getDockRectSymbol = dlsym(handle, "SLSGetDockRectWithOrientation")
        else {
            dlclose(handle)
            return nil
        }

        self.handle = handle
        slsMainConnectionID = unsafeBitCast(mainConnectionIDSymbol, to: SLSMainConnectionIDFunction.self)
        slsGetDockRectWithOrientation = unsafeBitCast(getDockRectSymbol, to: SLSGetDockRectWithOrientationFunction.self)
    }

    deinit {
        dlclose(handle)
    }

    func currentDockRect() -> CGRect? {
        var rect = CGRect.zero
        var orientation: Int32 = -1
        var reason: Int32 = -1
        let result = slsGetDockRectWithOrientation(slsMainConnectionID(), &rect, &orientation, &reason)
        guard result == 0, !rect.isNull, !rect.isEmpty else {
            return nil
        }

        return rect
    }
}

private extension CGRect {
    var area: CGFloat {
        guard !isNull, !isEmpty else {
            return 0
        }

        return width * height
    }
}
