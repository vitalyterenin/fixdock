import AppKit
import CoreGraphics
import Darwin
import Foundation

typealias CGSConnectionID = Int32
typealias CGSWindowID = UInt32
typealias CGSSpaceID = UInt64

enum ExperimentError: Error, CustomStringConvertible {
    case dlopenFailed(String)
    case missingSymbol(String)
    case missingTargetDisplay(CGDirectDisplayID)
    case missingTargetManagedDisplay(CGDirectDisplayID)
    case missingApplyFlag
    case invalidArguments(String)

    var description: String {
        switch self {
        case .dlopenFailed(let message):
            "Не удалось загрузить SkyLight: \(message)"
        case .missingSymbol(let name):
            "Не найден символ SkyLight: \(name)"
        case .missingTargetDisplay(let displayID):
            "Не найден CG display \(displayID)"
        case .missingTargetManagedDisplay(let displayID):
            "Не найден managed display для CG display \(displayID)"
        case .missingApplyFlag:
            "Write-команда требует явный флаг --apply"
        case .invalidArguments(let message):
            message
        }
    }
}

struct Arguments {
    var targetDisplayID: CGDirectDisplayID?
    var roleToSet: Int32?
    var roleScanRange: ClosedRange<Int32> = 0...15
    var testDockRect = false
    var testDockRectReason = false
    var keepDockRect = false
    var apply = false
    var help = false

    init(_ rawArguments: [String]) throws {
        var index = 1
        while index < rawArguments.count {
            let argument = rawArguments[index]

            switch argument {
            case "--help", "-h":
                help = true
            case "--apply":
                apply = true
            case "--target-display":
                index += 1
                guard index < rawArguments.count, let value = UInt32(rawArguments[index]) else {
                    throw ExperimentError.invalidArguments("--target-display требует числовой CGDirectDisplayID")
                }
                targetDisplayID = CGDirectDisplayID(value)
            case "--set-role-window":
                index += 1
                guard index < rawArguments.count, let value = Int32(rawArguments[index]) else {
                    throw ExperimentError.invalidArguments("--set-role-window требует числовой role")
                }
                roleToSet = value
            case "--test-dock-rect":
                testDockRect = true
            case "--test-dock-rect-reason":
                testDockRectReason = true
            case "--keep-dock-rect":
                keepDockRect = true
            case "--scan-roles":
                index += 1
                guard index < rawArguments.count else {
                    throw ExperimentError.invalidArguments("--scan-roles требует диапазон вида 0...32")
                }
                roleScanRange = try Self.parseRange(rawArguments[index])
            default:
                throw ExperimentError.invalidArguments("Неизвестный аргумент: \(argument)")
            }

            index += 1
        }
    }

    private static func parseRange(_ value: String) throws -> ClosedRange<Int32> {
        let separators = ["...", "..", "-"]
        for separator in separators where value.contains(separator) {
            let parts = value.components(separatedBy: separator)
            guard
                parts.count == 2,
                let lower = Int32(parts[0]),
                let upper = Int32(parts[1]),
                lower <= upper
            else {
                throw ExperimentError.invalidArguments("--scan-roles получил некорректный диапазон: \(value)")
            }
            return lower...upper
        }

        guard let role = Int32(value) else {
            throw ExperimentError.invalidArguments("--scan-roles получил некорректный диапазон: \(value)")
        }
        return role...role
    }
}

final class SkyLight {
    private let handle: UnsafeMutableRawPointer

    private typealias SLSMainConnectionIDFunction = @convention(c) () -> CGSConnectionID
    private typealias SLSCopyManagedDisplaysFunction = @convention(c) (CGSConnectionID) -> Unmanaged<CFArray>?
    private typealias SLSCopyBestManagedDisplayForRectFunction = @convention(c) (CGSConnectionID, CGRect) -> Unmanaged<CFString>?
    private typealias SLSManagedDisplayGetCurrentSpaceFunction = @convention(c) (CGSConnectionID, CFString) -> CGSSpaceID
    private typealias SLSManagedDisplaysCopyRoleWindowsFunction = @convention(c) (CGSConnectionID, CFArray, Int32) -> Unmanaged<CFArray>?
    private typealias SLSManagedDisplaySetRoleWindowFunction = @convention(c) (CGSConnectionID, CFString, Int32, CGSWindowID) -> Int32
    private typealias SLSGetDockRectWithOrientationFunction = @convention(c) (CGSConnectionID, UnsafeMutablePointer<CGRect>, UnsafeMutablePointer<Int32>, UnsafeMutablePointer<Int32>) -> Int32
    private typealias SLSSetDockRectWithOrientationFunction = @convention(c) (CGSConnectionID, CGRect, Int32, Int32) -> Int32
    private typealias SLSGetDockRectWithReasonFunction = @convention(c) (CGSConnectionID, UnsafeMutablePointer<CGRect>, UnsafeMutablePointer<Int32>) -> Int32
    private typealias SLSSetDockRectWithReasonFunction = @convention(c) (CGSConnectionID, CGRect, Int32) -> Int32

    private let slsMainConnectionID: SLSMainConnectionIDFunction
    private let slsCopyManagedDisplays: SLSCopyManagedDisplaysFunction
    private let slsCopyBestManagedDisplayForRect: SLSCopyBestManagedDisplayForRectFunction
    private let slsManagedDisplayGetCurrentSpace: SLSManagedDisplayGetCurrentSpaceFunction
    private let slsManagedDisplaysCopyRoleWindows: SLSManagedDisplaysCopyRoleWindowsFunction
    private let slsManagedDisplaySetRoleWindow: SLSManagedDisplaySetRoleWindowFunction
    private let slsGetDockRectWithOrientation: SLSGetDockRectWithOrientationFunction
    private let slsSetDockRectWithOrientation: SLSSetDockRectWithOrientationFunction
    private let slsGetDockRectWithReason: SLSGetDockRectWithReasonFunction?
    private let slsSetDockRectWithReason: SLSSetDockRectWithReasonFunction?

    init() throws {
        let path = "/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight"
        guard let handle = dlopen(path, RTLD_LAZY | RTLD_LOCAL) else {
            throw ExperimentError.dlopenFailed(String(cString: dlerror()))
        }

        self.handle = handle
        slsMainConnectionID = try Self.load("SLSMainConnectionID", from: handle)
        slsCopyManagedDisplays = try Self.load("SLSCopyManagedDisplays", from: handle)
        slsCopyBestManagedDisplayForRect = try Self.load("SLSCopyBestManagedDisplayForRect", from: handle)
        slsManagedDisplayGetCurrentSpace = try Self.load("SLSManagedDisplayGetCurrentSpace", from: handle)
        slsManagedDisplaysCopyRoleWindows = try Self.load("SLSManagedDisplaysCopyRoleWindows", from: handle)
        slsManagedDisplaySetRoleWindow = try Self.load("SLSManagedDisplaySetRoleWindow", from: handle)
        slsGetDockRectWithOrientation = try Self.load("SLSGetDockRectWithOrientation", from: handle)
        slsSetDockRectWithOrientation = try Self.load("SLSSetDockRectWithOrientation", from: handle)
        slsGetDockRectWithReason = Self.loadOptional("SLSGetDockRectWithReason", from: handle)
        slsSetDockRectWithReason = Self.loadOptional("SLSSetDockRectWithReason", from: handle)
    }

    deinit {
        dlclose(handle)
    }

    var connectionID: CGSConnectionID {
        slsMainConnectionID()
    }

    func copyManagedDisplays(connectionID: CGSConnectionID) -> [String] {
        guard let unmanaged = slsCopyManagedDisplays(connectionID) else {
            return []
        }

        return (unmanaged.takeRetainedValue() as NSArray).compactMap { $0 as? String }
    }

    func bestManagedDisplay(connectionID: CGSConnectionID, for rect: CGRect) -> String? {
        slsCopyBestManagedDisplayForRect(connectionID, rect)?.takeRetainedValue() as String?
    }

    func currentSpace(connectionID: CGSConnectionID, managedDisplay: String) -> CGSSpaceID {
        slsManagedDisplayGetCurrentSpace(connectionID, managedDisplay as CFString)
    }

    func roleWindows(connectionID: CGSConnectionID, managedDisplays: [String], role: Int32) -> [CGSWindowID] {
        guard let unmanaged = slsManagedDisplaysCopyRoleWindows(
            connectionID,
            managedDisplays as CFArray,
            role
        ) else {
            return []
        }

        return (unmanaged.takeRetainedValue() as NSArray).compactMap { value in
            (value as? NSNumber).map { CGSWindowID($0.uint32Value) }
        }
    }

    func setRoleWindow(connectionID: CGSConnectionID, managedDisplay: String, role: Int32, windowID: CGSWindowID) -> Int32 {
        slsManagedDisplaySetRoleWindow(connectionID, managedDisplay as CFString, role, windowID)
    }

    func dockRect(connectionID: CGSConnectionID) -> DockRectSnapshot? {
        var rect = CGRect.zero
        var orientation: Int32 = -1
        var reason: Int32 = -1
        let result = slsGetDockRectWithOrientation(connectionID, &rect, &orientation, &reason)
        guard result == 0 else {
            return nil
        }

        return DockRectSnapshot(rect: rect, orientation: orientation, reason: reason)
    }

    func setDockRect(connectionID: CGSConnectionID, snapshot: DockRectSnapshot) -> Int32 {
        slsSetDockRectWithOrientation(connectionID, snapshot.rect, snapshot.orientation, snapshot.reason)
    }

    func dockRectWithReason(connectionID: CGSConnectionID) -> DockRectReasonSnapshot? {
        guard let slsGetDockRectWithReason else {
            return nil
        }

        var rect = CGRect.zero
        var reason: Int32 = -1
        let result = slsGetDockRectWithReason(connectionID, &rect, &reason)
        guard result == 0 else {
            return nil
        }

        return DockRectReasonSnapshot(rect: rect, reason: reason)
    }

    func setDockRectWithReason(connectionID: CGSConnectionID, snapshot: DockRectReasonSnapshot) -> Int32? {
        guard let slsSetDockRectWithReason else {
            return nil
        }

        return slsSetDockRectWithReason(connectionID, snapshot.rect, snapshot.reason)
    }

    private static func load<T>(_ name: String, from handle: UnsafeMutableRawPointer) throws -> T {
        guard let symbol = dlsym(handle, name) else {
            throw ExperimentError.missingSymbol(name)
        }

        return unsafeBitCast(symbol, to: T.self)
    }

    private static func loadOptional<T>(_ name: String, from handle: UnsafeMutableRawPointer) -> T? {
        guard let symbol = dlsym(handle, name) else {
            return nil
        }

        return unsafeBitCast(symbol, to: T.self)
    }
}

struct DisplaySnapshot {
    let id: CGDirectDisplayID
    let bounds: CGRect
    let isMain: Bool
    let managedDisplay: String?
}

struct DockWindow {
    let windowID: CGSWindowID
    let ownerPID: pid_t
    let name: String
    let layer: Int
    let bounds: CGRect
}

struct DockRectSnapshot {
    let rect: CGRect
    let orientation: Int32
    let reason: Int32
}

struct DockRectReasonSnapshot {
    let rect: CGRect
    let reason: Int32
}

enum RectEdge: String {
    case bottom
    case top
    case left
    case right
}

func printUsage() {
    print("""
    SkyLightDockDisplaySwitch

    Read-only диагностика:
      swift run SkyLightDockDisplaySwitch
      swift run SkyLightDockDisplaySwitch --target-display <CGDirectDisplayID>

    Поиск role windows:
      swift run SkyLightDockDisplaySwitch --scan-roles 0...32

    Write-эксперимент, только после ручной проверки role:
      swift run SkyLightDockDisplaySwitch --target-display <CGDirectDisplayID> --set-role-window <role> --apply

    Reversible write-тест Dock rect:
      swift run SkyLightDockDisplaySwitch --target-display <CGDirectDisplayID> --test-dock-rect --apply
      swift run SkyLightDockDisplaySwitch --target-display <CGDirectDisplayID> --test-dock-rect --keep-dock-rect --apply

    Reversible write-тест Dock rect with reason:
      swift run SkyLightDockDisplaySwitch --target-display <CGDirectDisplayID> --test-dock-rect-reason --apply

    Цель: проверить перенос Dock через SkyLight managed display role window без движения курсора.
    """)
}

func activeDisplays(skyLight: SkyLight, connectionID: CGSConnectionID) -> [DisplaySnapshot] {
    var count: UInt32 = 0
    var ids = [CGDirectDisplayID](repeating: 0, count: 32)
    guard CGGetActiveDisplayList(UInt32(ids.count), &ids, &count) == .success else {
        return []
    }

    return ids.prefix(Int(count)).map { id in
        let bounds = CGDisplayBounds(id)
        return DisplaySnapshot(
            id: id,
            bounds: bounds,
            isMain: id == CGMainDisplayID(),
            managedDisplay: skyLight.bestManagedDisplay(connectionID: connectionID, for: bounds)
        )
    }
}

func dockWindows() -> [DockWindow] {
    guard let windowList = CGWindowListCopyWindowInfo([.optionAll], kCGNullWindowID) as? [[String: Any]] else {
        return []
    }

    return windowList.compactMap { window in
        guard
            let owner = window[kCGWindowOwnerName as String] as? String,
            owner == "Dock",
            let windowNumber = window[kCGWindowNumber as String] as? NSNumber,
            let ownerPID = window[kCGWindowOwnerPID as String] as? NSNumber,
            let layer = window[kCGWindowLayer as String] as? Int,
            let boundsDictionary = window[kCGWindowBounds as String] as? NSDictionary,
            let bounds = CGRect(dictionaryRepresentation: boundsDictionary)
        else {
            return nil
        }

        return DockWindow(
            windowID: CGSWindowID(windowNumber.uint32Value),
            ownerPID: pid_t(ownerPID.int32Value),
            name: window[kCGWindowName as String] as? String ?? "",
            layer: layer,
            bounds: bounds
        )
    }
}

func currentDockDisplayID(dockWindow: DockWindow?, displays: [DisplaySnapshot]) -> CGDirectDisplayID? {
    guard let dockWindow else {
        return nil
    }

    return displays
        .map { display in
            (id: display.id, area: display.bounds.intersection(dockWindow.bounds).area)
        }
        .max { lhs, rhs in lhs.area < rhs.area }
        .flatMap { $0.area > 0 ? $0.id : nil }
}

func primaryDockWindow(from dockWindows: [DockWindow]) -> DockWindow? {
    dockWindows.first { $0.name == "Dock" && $0.layer == 20 } ??
        dockWindows.first { $0.name == "Dock" } ??
        dockWindows.first
}

func cursorLocation() -> CGPoint {
    CGEvent(source: nil)?.location ?? .zero
}

func format(_ rect: CGRect) -> String {
    "x=\(Int(rect.origin.x)) y=\(Int(rect.origin.y)) w=\(Int(rect.width)) h=\(Int(rect.height))"
}

func printDisplaySnapshot(_ displays: [DisplaySnapshot], skyLight: SkyLight, connectionID: CGSConnectionID) {
    print("CG displays:")
    for display in displays {
        let marker = display.isMain ? " main" : ""
        let managed = display.managedDisplay ?? "nil"
        let space = display.managedDisplay.map { skyLight.currentSpace(connectionID: connectionID, managedDisplay: $0) }
        print("  \(display.id)\(marker): \(format(display.bounds)) managed=\(managed) currentSpace=\(space.map(String.init) ?? "nil")")
    }
}

func printDockWindows(_ windows: [DockWindow], displays: [DisplaySnapshot]) {
    print("Dock windows:")
    if windows.isEmpty {
        print("  none")
    }

    for window in windows {
        let displayID = currentDockDisplayID(dockWindow: window, displays: displays).map(String.init) ?? "nil"
        print("  id=\(window.windowID) pid=\(window.ownerPID) layer=\(window.layer) name=\"\(window.name)\" display=\(displayID) bounds=\(format(window.bounds))")
    }
}

func printDockRect(_ snapshot: DockRectSnapshot?, displays: [DisplaySnapshot]) {
    guard let snapshot else {
        print("SkyLight Dock rect: nil")
        return
    }

    let displayMatches: [(id: CGDirectDisplayID, area: CGFloat)] = displays.map { display in
        (id: display.id, area: display.bounds.intersection(snapshot.rect).area)
    }
    let bestMatch = displayMatches.max { lhs, rhs in lhs.area < rhs.area }
    let displayID = if let bestMatch, bestMatch.area > 0 {
        String(bestMatch.id)
    } else {
        "nil"
    }

    print("SkyLight Dock rect: display=\(displayID) orientation=\(snapshot.orientation) reason=\(snapshot.reason) rect=\(format(snapshot.rect))")
}

func printDockRectWithReason(_ snapshot: DockRectReasonSnapshot?, displays: [DisplaySnapshot]) {
    guard let snapshot else {
        print("SkyLight Dock rect with reason: nil")
        return
    }

    let displayMatches: [(id: CGDirectDisplayID, area: CGFloat)] = displays.map { display in
        (id: display.id, area: display.bounds.intersection(snapshot.rect).area)
    }
    let bestMatch = displayMatches.max { lhs, rhs in lhs.area < rhs.area }
    let displayID = if let bestMatch, bestMatch.area > 0 {
        String(bestMatch.id)
    } else {
        "nil"
    }

    print("SkyLight Dock rect with reason: display=\(displayID) reason=\(snapshot.reason) rect=\(format(snapshot.rect))")
}

func edge(for dockRect: CGRect, in displayBounds: CGRect) -> RectEdge {
    let distances: [(edge: RectEdge, distance: CGFloat)] = [
        (.bottom, abs(displayBounds.maxY - dockRect.maxY)),
        (.top, abs(displayBounds.minY - dockRect.minY)),
        (.left, abs(displayBounds.minX - dockRect.minX)),
        (.right, abs(displayBounds.maxX - dockRect.maxX))
    ]

    return distances.min { lhs, rhs in lhs.distance < rhs.distance }?.edge ?? .bottom
}

func relocatedDockRect(currentRect: CGRect, currentDisplay: CGRect, targetDisplay: CGRect) -> CGRect {
    switch edge(for: currentRect, in: currentDisplay) {
    case .bottom:
        return CGRect(
            x: targetDisplay.midX - currentRect.width / 2,
            y: targetDisplay.maxY - currentRect.height,
            width: currentRect.width,
            height: currentRect.height
        )
    case .top:
        return CGRect(
            x: targetDisplay.midX - currentRect.width / 2,
            y: targetDisplay.minY,
            width: currentRect.width,
            height: currentRect.height
        )
    case .left:
        return CGRect(
            x: targetDisplay.minX,
            y: targetDisplay.midY - currentRect.height / 2,
            width: currentRect.width,
            height: currentRect.height
        )
    case .right:
        return CGRect(
            x: targetDisplay.maxX - currentRect.width,
            y: targetDisplay.midY - currentRect.height / 2,
            width: currentRect.width,
            height: currentRect.height
        )
    }
}

func printRoleWindows(
    skyLight: SkyLight,
    connectionID: CGSConnectionID,
    managedDisplays: [String],
    dockWindowIDs: Set<CGSWindowID>,
    roleRange: ClosedRange<Int32>
) {
    print("Managed display role windows:")
    for role in roleRange {
        let windowsByDisplay = managedDisplays.map { display in
            (
                display: display,
                windows: skyLight.roleWindows(
                    connectionID: connectionID,
                    managedDisplays: [display],
                    role: role
                )
            )
        }
        let allWindows = windowsByDisplay.flatMap(\.windows)
        guard !allWindows.isEmpty || allWindows.contains(where: { dockWindowIDs.contains($0) }) else {
            continue
        }

        let match = allWindows.contains { dockWindowIDs.contains($0) }
        print("  role=\(role) matchesDock=\(match)")
        for item in windowsByDisplay where !item.windows.isEmpty {
            print("    display=\(item.display) windows=\(item.windows)")
        }
    }
}

func selectedTargetManagedDisplay(
    targetDisplayID: CGDirectDisplayID?,
    displays: [DisplaySnapshot]
) throws -> (DisplaySnapshot, String)? {
    guard let targetDisplayID else {
        return nil
    }

    guard let display = displays.first(where: { $0.id == targetDisplayID }) else {
        throw ExperimentError.missingTargetDisplay(targetDisplayID)
    }

    guard let managedDisplay = display.managedDisplay else {
        throw ExperimentError.missingTargetManagedDisplay(targetDisplayID)
    }

    return (display, managedDisplay)
}

func run() throws {
    let arguments = try Arguments(CommandLine.arguments)
    if arguments.help {
        printUsage()
        return
    }

    if (arguments.roleToSet != nil || arguments.testDockRect || arguments.testDockRectReason) && !arguments.apply {
        throw ExperimentError.missingApplyFlag
    }

    let skyLight = try SkyLight()
    let connectionID = skyLight.connectionID
    let displays = activeDisplays(skyLight: skyLight, connectionID: connectionID)
    let managedDisplays = skyLight.copyManagedDisplays(connectionID: connectionID)
    let windows = dockWindows()
    let dockWindow = primaryDockWindow(from: windows)
    let dockWindowIDs = Set(windows.map(\.windowID))
    let dockRect = skyLight.dockRect(connectionID: connectionID)
    let dockRectWithReason = skyLight.dockRectWithReason(connectionID: connectionID)
    let beforeCursor = cursorLocation()
    let beforeDockDisplayID = currentDockDisplayID(dockWindow: dockWindow, displays: displays)

    print("SkyLight connection: \(connectionID)")
    print("Cursor before: x=\(beforeCursor.x) y=\(beforeCursor.y)")
    print("Managed displays: \(managedDisplays)")
    printDisplaySnapshot(displays, skyLight: skyLight, connectionID: connectionID)
    printDockRect(dockRect, displays: displays)
    printDockRectWithReason(dockRectWithReason, displays: displays)
    printDockWindows(windows, displays: displays)
    print("Primary Dock window: \(dockWindow.map { String($0.windowID) } ?? "nil")")
    print("Current Dock display: \(beforeDockDisplayID.map(String.init) ?? "nil")")
    printRoleWindows(
        skyLight: skyLight,
        connectionID: connectionID,
        managedDisplays: managedDisplays,
        dockWindowIDs: dockWindowIDs,
        roleRange: arguments.roleScanRange
    )

    if let role = arguments.roleToSet {
        guard let dockWindow else {
            throw ExperimentError.invalidArguments("Не найдено Dock window для set-role-window")
        }

        guard let (_, targetManagedDisplay) = try selectedTargetManagedDisplay(
            targetDisplayID: arguments.targetDisplayID,
            displays: displays
        ) else {
            throw ExperimentError.invalidArguments("--set-role-window требует --target-display")
        }

        print("Applying SLSManagedDisplaySetRoleWindow display=\(targetManagedDisplay) role=\(role) windowID=\(dockWindow.windowID)")
        let result = skyLight.setRoleWindow(
            connectionID: connectionID,
            managedDisplay: targetManagedDisplay,
            role: role,
            windowID: dockWindow.windowID
        )
        print("SLSManagedDisplaySetRoleWindow result: \(result)")

        Thread.sleep(forTimeInterval: 0.5)
        let afterWindows = dockWindows()
        let afterDockWindow = primaryDockWindow(from: afterWindows)
        let afterDockDisplayID = currentDockDisplayID(dockWindow: afterDockWindow, displays: displays)
        printDockWindows(afterWindows, displays: displays)
        print("Dock display after: \(afterDockDisplayID.map(String.init) ?? "nil")")
    }

    if arguments.testDockRect {
        guard let dockRect else {
            throw ExperimentError.invalidArguments("Не удалось прочитать исходный Dock rect")
        }

        guard let target = displays.first(where: { $0.id == arguments.targetDisplayID }) else {
            throw ExperimentError.invalidArguments("--test-dock-rect требует --target-display")
        }

        let sourceDisplay = displays
            .map { display in
                (display: display, area: display.bounds.intersection(dockRect.rect).area)
            }
            .max { lhs, rhs in lhs.area < rhs.area }?
            .display ?? target
        let targetRect = relocatedDockRect(
            currentRect: dockRect.rect,
            currentDisplay: sourceDisplay.bounds,
            targetDisplay: target.bounds
        )
        let targetSnapshot = DockRectSnapshot(
            rect: targetRect,
            orientation: dockRect.orientation,
            reason: dockRect.reason
        )

        print("Applying SLSSetDockRectWithOrientation targetDisplay=\(target.id) rect=\(format(targetRect)) orientation=\(dockRect.orientation) reason=\(dockRect.reason)")
        print("SLSSetDockRectWithOrientation result: \(skyLight.setDockRect(connectionID: connectionID, snapshot: targetSnapshot))")
        Thread.sleep(forTimeInterval: 1.0)
        printDockRect(skyLight.dockRect(connectionID: connectionID), displays: displays)
        printDockWindows(dockWindows(), displays: displays)

        if !arguments.keepDockRect {
            print("Restoring original Dock rect: \(format(dockRect.rect))")
            print("SLSSetDockRectWithOrientation restore result: \(skyLight.setDockRect(connectionID: connectionID, snapshot: dockRect))")
            Thread.sleep(forTimeInterval: 0.5)
            printDockRect(skyLight.dockRect(connectionID: connectionID), displays: displays)
        }
    }

    if arguments.testDockRectReason {
        guard let dockRectWithReason else {
            throw ExperimentError.invalidArguments("Не удалось прочитать исходный Dock rect через SLSGetDockRectWithReason")
        }

        guard let target = displays.first(where: { $0.id == arguments.targetDisplayID }) else {
            throw ExperimentError.invalidArguments("--test-dock-rect-reason требует --target-display")
        }

        let sourceDisplay = displays
            .map { display in
                (display: display, area: display.bounds.intersection(dockRectWithReason.rect).area)
            }
            .max { lhs, rhs in lhs.area < rhs.area }?
            .display ?? target
        let targetRect = relocatedDockRect(
            currentRect: dockRectWithReason.rect,
            currentDisplay: sourceDisplay.bounds,
            targetDisplay: target.bounds
        )
        let targetSnapshot = DockRectReasonSnapshot(
            rect: targetRect,
            reason: dockRectWithReason.reason
        )

        print("Applying SLSSetDockRectWithReason targetDisplay=\(target.id) rect=\(format(targetRect)) reason=\(dockRectWithReason.reason)")
        print("SLSSetDockRectWithReason result: \(skyLight.setDockRectWithReason(connectionID: connectionID, snapshot: targetSnapshot).map(String.init) ?? "missing")")
        Thread.sleep(forTimeInterval: 1.0)
        printDockRectWithReason(skyLight.dockRectWithReason(connectionID: connectionID), displays: displays)
        printDockWindows(dockWindows(), displays: displays)

        if !arguments.keepDockRect {
            print("Restoring original Dock rect with reason: \(format(dockRectWithReason.rect))")
            print("SLSSetDockRectWithReason restore result: \(skyLight.setDockRectWithReason(connectionID: connectionID, snapshot: dockRectWithReason).map(String.init) ?? "missing")")
            Thread.sleep(forTimeInterval: 0.5)
            printDockRectWithReason(skyLight.dockRectWithReason(connectionID: connectionID), displays: displays)
        }
    }

    let afterCursor = cursorLocation()
    print("Cursor after: x=\(afterCursor.x) y=\(afterCursor.y)")
    print("Cursor unchanged: \(beforeCursor == afterCursor)")
}

do {
    try run()
} catch let error as ExperimentError {
    fputs("error: \(error.description)\n", stderr)
    exit(2)
} catch {
    fputs("error: \(error)\n", stderr)
    exit(1)
}

private extension CGRect {
    var area: CGFloat {
        guard !isNull, !isEmpty else {
            return 0
        }

        return width * height
    }
}
