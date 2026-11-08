import XCTest
@testable import Fixdock

final class DockLockPolicyTests: XCTestCase {
    private let displays: Set<UInt32> = [1, 2]

    private func allowed(_ policy: inout DockLockPolicy, current: UInt32?, target: UInt32? = 1,
                         guardRunning: Bool = true, available: Set<UInt32>? = nil) -> Bool {
        policy.allowsSwitching(selectedDisplayID: target, currentDisplayID: current,
                               availableDisplayIDs: available ?? displays, edgeGuardRunning: guardRunning)
    }

    func testFullscreenObservationLossNeverUnlocks() {
        var policy = DockLockPolicy()
        for current: UInt32? in [1, nil, nil, 2, nil, 1] {
            XCTAssertFalse(allowed(&policy, current: current))
        }
    }

    func testUnexpectedOtherDisplayAtLaunchStaysLocked() {
        var policy = DockLockPolicy()
        XCTAssertFalse(allowed(&policy, current: 2))
    }

    func testExplicitTransferRelocksPermanentlyOnArrival() {
        var policy = DockLockPolicy()
        policy.requestTransfer(to: 2)
        XCTAssertTrue(allowed(&policy, current: 1, target: 2))
        XCTAssertFalse(allowed(&policy, current: nil, target: 2))
        XCTAssertTrue(allowed(&policy, current: 1, target: 2))
        XCTAssertFalse(allowed(&policy, current: 2, target: 2))
        XCTAssertNil(policy.pendingDisplayID)
        for current: UInt32? in [nil, 1, 2] {
            XCTAssertFalse(allowed(&policy, current: current, target: 2))
        }
    }

    func testTransferRequiresLiveGuardAndKnownConnectedDisplays() {
        var policy = DockLockPolicy()
        policy.requestTransfer(to: 2)
        XCTAssertFalse(allowed(&policy, current: 1, target: 2, guardRunning: false))
        XCTAssertFalse(allowed(&policy, current: 1, target: 2, available: [1]))
        XCTAssertFalse(allowed(&policy, current: 99, target: 2))
        XCTAssertFalse(allowed(&policy, current: 1, target: nil))
    }

    func testTransferRequestDoesNotAuthorizeAnotherTarget() {
        var policy = DockLockPolicy()
        policy.requestTransfer(to: 2)
        XCTAssertFalse(allowed(&policy, current: 2, target: 1))
    }
}
