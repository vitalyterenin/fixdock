import Testing
@testable import Fixdock

struct DockLockPolicyTests {
    private let displays: Set<UInt32> = [1, 2]

    private func allowed(_ policy: inout DockLockPolicy, current: UInt32?, target: UInt32? = 1,
                         guardRunning: Bool = true, available: Set<UInt32>? = nil) -> Bool {
        policy.allowsSwitching(selectedDisplayID: target, currentDisplayID: current,
                               availableDisplayIDs: available ?? displays, edgeGuardRunning: guardRunning)
    }

    @Test func testFullscreenObservationLossNeverUnlocks() {
        var policy = DockLockPolicy()
        for current: UInt32? in [1, nil, nil, 2, nil, 1] {
            #expect(!(allowed(&policy, current: current)))
        }
    }

    @Test func testUnexpectedOtherDisplayAtLaunchStaysLocked() {
        var policy = DockLockPolicy()
        #expect(!(allowed(&policy, current: 2)))
    }

    @Test func testExplicitTransferRelocksPermanentlyOnArrival() {
        var policy = DockLockPolicy()
        policy.requestTransfer(to: 2)
        #expect(allowed(&policy, current: 1, target: 2))
        #expect(!(allowed(&policy, current: nil, target: 2)))
        #expect(allowed(&policy, current: 1, target: 2))
        #expect(!(allowed(&policy, current: 2, target: 2)))
        #expect(policy.pendingDisplayID == nil)
        for current: UInt32? in [nil, 1, 2] {
            #expect(!(allowed(&policy, current: current, target: 2)))
        }
    }

    @Test func testTransferRequiresLiveGuardAndKnownConnectedDisplays() {
        var policy = DockLockPolicy()
        policy.requestTransfer(to: 2)
        #expect(!(allowed(&policy, current: 1, target: 2, guardRunning: false)))
        #expect(!(allowed(&policy, current: 1, target: 2, available: [1])))
        #expect(!(allowed(&policy, current: 99, target: 2)))
        #expect(!(allowed(&policy, current: 1, target: nil)))
    }

    @Test func testTransferRequestDoesNotAuthorizeAnotherTarget() {
        var policy = DockLockPolicy()
        policy.requestTransfer(to: 2)
        #expect(!(allowed(&policy, current: 2, target: 1)))
    }
}
