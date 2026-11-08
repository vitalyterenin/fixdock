import CoreGraphics

/// A missing or unexpected Dock observation never grants permission to move it.
struct DockLockPolicy {
    private(set) var pendingDisplayID: CGDirectDisplayID?

    mutating func requestTransfer(to displayID: CGDirectDisplayID) {
        pendingDisplayID = displayID
    }

    mutating func allowsSwitching(
        selectedDisplayID: CGDirectDisplayID?,
        currentDisplayID: CGDirectDisplayID?,
        availableDisplayIDs: Set<CGDirectDisplayID>,
        edgeGuardRunning: Bool
    ) -> Bool {
        guard let selectedDisplayID, availableDisplayIDs.contains(selectedDisplayID) else {
            return false
        }
        if currentDisplayID == selectedDisplayID {
            pendingDisplayID = nil
            return false
        }
        guard let currentDisplayID, availableDisplayIDs.contains(currentDisplayID) else {
            return false
        }
        return pendingDisplayID == selectedDisplayID && edgeGuardRunning
    }
}
