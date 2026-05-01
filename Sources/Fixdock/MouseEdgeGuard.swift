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
    private var didRequestAccessibility = false

    var isRunning: Bool {
        eventTap != nil
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
        guard eventTap == nil else {
            return true
        }

        guard isAccessibilityTrusted else {
            requestAccessibilityOnce()
            return false
        }

        let eventMask = CGEventMask(
            (1 << CGEventType.mouseMoved.rawValue) |
            (1 << CGEventType.tapDisabledByTimeout.rawValue) |
            (1 << CGEventType.tapDisabledByUserInput.rawValue)
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
        return true
    }

    private func requestAccessibilityOnce() {
        guard !didRequestAccessibility else {
            return
        }

        didRequestAccessibility = true
        let promptKey = "AXTrustedCheckOptionPrompt"
        AXIsProcessTrustedWithOptions([promptKey: true] as CFDictionary)
    }

    func stop() {
        if let eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
            self.eventTap = nil
        }

        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
            self.runLoopSource = nil
        }
    }

    private func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let eventTap {
                CGEvent.tapEnable(tap: eventTap, enable: true)
            }
            return Unmanaged.passUnretained(event)
        }

        guard type == .mouseMoved else {
            return Unmanaged.passUnretained(event)
        }

        if shouldSuppressDockTrigger(event: event) {
            return nil
        }

        return Unmanaged.passUnretained(event)
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
        guard let previousLocation else {
            return false
        }

        let frame = display.quartzFrame
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
