import CoreGraphics
import Testing
@testable import Fixdock

struct MouseEdgeGuardTests {
    private let display = DisplayInfo(
        id: 2, name: "Other display",
        appKitFrame: CGRect(x: 100, y: 100, width: 100, height: 100),
        quartzFrame: CGRect(x: 100, y: 100, width: 100, height: 100),
        isMain: false
    )

    private func guardFor(edge: DockEdge = .bottom, target: UInt32? = 1) -> MouseEdgeGuard {
        let guardInstance = MouseEdgeGuard()
        guardInstance.update(displays: [display], targetDisplayID: target, dockEdge: edge)
        return guardInstance
    }

    // Events are inspected locally; nothing is posted to the system or cursor.
    private func isSuppressed(_ guardInstance: MouseEdgeGuard, at point: CGPoint) throws -> Bool {
        let event = try #require(CGEvent(mouseEventSource: nil, mouseType: .mouseMoved,
                                          mouseCursorPosition: point, mouseButton: .left))
        return withExtendedLifetime(event) {
            guardInstance.handle(type: .mouseMoved, event: event) == nil
        }
    }

    @Test func testFirstEventAtEveryForbiddenEdgeIsSuppressed() throws {
        let points: [(DockEdge, CGPoint)] = [
            (.bottom, CGPoint(x: 150, y: 199)),
            (.top, CGPoint(x: 150, y: 100)),
            (.left, CGPoint(x: 100, y: 150)),
            (.right, CGPoint(x: 199, y: 150))
        ]
        for (edge, point) in points {
            let guardInstance = guardFor(edge: edge)
            #expect(try isSuppressed(guardInstance, at: point), "First event should be blocked at \(edge)")
        }
    }

    @Test func testPointsOutsideDisplayAndAwayFromEdgePassThrough() throws {
        let guardInstance = guardFor()
        for point in [CGPoint(x: 150, y: 250), CGPoint(x: 50, y: 199),
                      CGPoint(x: 250, y: 199), CGPoint(x: 150, y: 150)] {
            #expect(!(try isSuppressed(guardInstance, at: point)))
        }
    }

    @Test func testSelectedDisplayAndMissingTargetPassThrough() throws {
        for target: UInt32? in [2, nil] {
            let guardInstance = guardFor(target: target)
            #expect(!(try isSuppressed(guardInstance, at: CGPoint(x: 150, y: 199))))
        }
    }

    @Test func testMovingAwayFromEdgePassesThrough() throws {
        let guardInstance = guardFor()
        #expect(try isSuppressed(guardInstance, at: CGPoint(x: 150, y: 199)))
        #expect(!(try isSuppressed(guardInstance, at: CGPoint(x: 150, y: 198))))
    }

    @Test func testStopDiscardsStalePointerLocation() throws {
        let guardInstance = guardFor()
        _ = try isSuppressed(guardInstance, at: CGPoint(x: 150, y: 250))
        guardInstance.stop()
        #expect(try isSuppressed(guardInstance, at: CGPoint(x: 150, y: 199)))
    }

    @Test func testOnlyDockHidingShortcutsAreSuppressed() throws {
        let guardInstance = guardFor()
        let cases: [(Int64, CGEventFlags, Bool)] = [
            (2, [.maskCommand, .maskAlternate], true),
            (0, [.maskSecondaryFn], true),
            (2, [.maskCommand], false),
            (2, [.maskCommand, .maskAlternate, .maskShift], false),
            (0, [], false),
            (1, [.maskSecondaryFn], false)
        ]
        for (keyCode, flags, suppressed) in cases {
            for type in [CGEventType.keyDown, .keyUp] {
                let event = try #require(CGEvent(keyboardEventSource: nil,
                                                  virtualKey: CGKeyCode(keyCode),
                                                  keyDown: type == .keyDown))
                event.flags = flags
                #expect((guardInstance.handle(type: type, event: event) == nil) == suppressed, "key=\(keyCode), flags=\(flags), type=\(type)")
            }
        }
    }
}
