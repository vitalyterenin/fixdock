import AppKit
import CoreGraphics

final class DisplayManager {
    var displays: [DisplayInfo] {
        NSScreen.screens.compactMap { screen in
            guard
                let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber
            else {
                return nil
            }

            let displayID = CGDirectDisplayID(number.uint32Value)
            return DisplayInfo(
                id: displayID,
                name: screen.localizedName,
                appKitFrame: screen.frame,
                quartzFrame: CGDisplayBounds(displayID),
                isMain: displayID == CGMainDisplayID()
            )
        }
        .sorted { lhs, rhs in
            if lhs.isMain != rhs.isMain {
                return lhs.isMain
            }

            if lhs.appKitFrame.minX != rhs.appKitFrame.minX {
                return lhs.appKitFrame.minX < rhs.appKitFrame.minX
            }

            return lhs.appKitFrame.minY < rhs.appKitFrame.minY
        }
    }

    func normalizedTargetDisplayID(preferredID: CGDirectDisplayID?) -> CGDirectDisplayID? {
        let currentDisplays = displays
        if let preferredID, currentDisplays.contains(where: { $0.id == preferredID }) {
            return preferredID
        }

        return currentDisplays.first(where: \.isMain)?.id ?? currentDisplays.first?.id
    }
}
