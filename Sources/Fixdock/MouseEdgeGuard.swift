import ApplicationServices
import CoreGraphics
import Foundation

final class MouseEdgeGuard {
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var displays: [DisplayInfo] = []
    private var targetDisplayID: CGDirectDisplayID?
    private var dockEdge: DockEdge = .bottom
    private var previousLocation: CGPoint?

    var isRunning: Bool {
        guard let eventTap, CFMachPortIsValid(eventTap) else { return false }
        return CGEvent.tapIsEnabled(tap: eventTap)
    }

    var isAccessibilityTrusted: Bool {
        AXIsProcessTrusted()
    }

    func update(displays: [DisplayInfo], targetDisplayID: CGDirectDisplayID?, dockEdge: DockEdge) {
        self.displays = displays
        self.targetDisplayID = targetDisplayID
        self.dockEdge = dockEdge
    }

    @discardableResult
    func start() -> Bool {
        if let eventTap {
            if CFMachPortIsValid(eventTap), isAccessibilityTrusted {
                if !CGEvent.tapIsEnabled(tap: eventTap) {
                    CGEvent.tapEnable(tap: eventTap, enable: true)
                }
                if isRunning { return true }
            }
            stop()
        }

        guard isAccessibilityTrusted else {
            return false
        }

        let eventMask = CGEventMask(
            (1 << CGEventType.mouseMoved.rawValue) |
            (1 << CGEventType.keyDown.rawValue) |
            (1 << CGEventType.keyUp.rawValue)
        )

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: { _, type, event, refcon in
                guard let refcon else {
                    return Unmanaged.passUnretained(event)
                }

                let guardInstance = Unmanaged<MouseEdgeGuard>.fromOpaque(refcon).takeUnretainedValue()
                return guardInstance.handle(type: type, event: event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            return false
        }

        eventTap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        if let runLoopSource {
            CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }
        CGEvent.tapEnable(tap: tap, enable: true)
        return isRunning
    }

    func stop() {
        previousLocation = nil
        if let eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
            CFMachPortInvalidate(eventTap)
            self.eventTap = nil
        }

        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
            self.runLoopSource = nil
        }
    }

    func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let eventTap {
                CGEvent.tapEnable(tap: eventTap, enable: true)
            }
            return Unmanaged.passUnretained(event)
        }

        if type == .keyDown || type == .keyUp {
            return shouldSuppressDockHidingShortcut(event: event) ? nil : Unmanaged.passUnretained(event)
        }

        guard type == .mouseMoved else {
            return Unmanaged.passUnretained(event)
        }

        if shouldSuppressDockTrigger(event: event) {
            return nil
        }

        return Unmanaged.passUnretained(event)
    }

    private func shouldSuppressDockHidingShortcut(event: CGEvent) -> Bool {
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        let modifiers = event.flags.intersection([
            .maskCommand,
            .maskAlternate,
            .maskControl,
            .maskShift,
            .maskSecondaryFn
        ])

        // macOS uses Option-Command-D and, on newer releases, Fn-A to toggle Dock visibility.
        return (keyCode == 2 && modifiers == [.maskCommand, .maskAlternate]) ||
            (keyCode == 0 && modifiers == [.maskSecondaryFn])
    }

    private func shouldSuppressDockTrigger(event: CGEvent) -> Bool {
        guard let targetDisplayID else {
            return false
        }

        let location = event.location
        defer {
            previousLocation = location
        }

        for display in displays where display.id != targetDisplayID {
            guard isAtDockTriggerEdge(location: location, previousLocation: previousLocation, display: display) else {
                continue
            }

            return true
        }

        return false
    }

    private func isAtDockTriggerEdge(location: CGPoint, previousLocation: CGPoint?, display: DisplayInfo) -> Bool {
        let frame = display.quartzFrame
        guard frame.contains(location) else { return false }
        let previousLocation = previousLocation ?? location
        let edgeThickness: CGFloat = 3

        switch dockEdge {
        case .bottom:
            return location.x >= frame.minX &&
                location.x <= frame.maxX &&
                location.y >= frame.maxY - edgeThickness &&
                location.y >= previousLocation.y
        case .top:
            return location.x >= frame.minX &&
                location.x <= frame.maxX &&
                location.y <= frame.minY + edgeThickness &&
                location.y <= previousLocation.y
        case .left:
            return location.y >= frame.minY &&
                location.y <= frame.maxY &&
                location.x <= frame.minX + edgeThickness &&
                location.x <= previousLocation.x
        case .right:
            return location.y >= frame.minY &&
                location.y <= frame.maxY &&
                location.x >= frame.maxX - edgeThickness &&
                location.x >= previousLocation.x
        }
    }
}
