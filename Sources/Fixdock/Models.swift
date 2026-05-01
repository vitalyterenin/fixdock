import AppKit
import CoreGraphics

enum DockEdge: String, CaseIterable, Sendable {
    case bottom
    case left
    case right
    case top

    var localizedTitle: String {
        switch self {
        case .bottom:
            "Снизу"
        case .left:
            "Слева"
        case .right:
            "Справа"
        case .top:
            "Сверху"
        }
    }

    static func fromDockPreference(_ value: String?) -> DockEdge {
        switch value?.lowercased() {
        case "left":
            .left
        case "right":
            .right
        case "top":
            .top
        default:
            .bottom
        }
    }
}

struct DisplayInfo: Identifiable, Equatable, Sendable {
    let id: CGDirectDisplayID
    let name: String
    let appKitFrame: CGRect
    let quartzFrame: CGRect
    let isMain: Bool

    var displayName: String {
        if isMain {
            "\(name) (основной)"
        } else {
            name
        }
    }
}
