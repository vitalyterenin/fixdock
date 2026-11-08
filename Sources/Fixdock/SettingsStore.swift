import CoreGraphics
import Foundation

struct DockVisibilitySnapshot: Codable {
    let isAutoHideEnabled: Bool
    let autoHideLockValue: Bool?
}

final class SettingsStore {
    private enum Key {
        static let targetDisplayID = "targetDisplayID"
        static let dockVisibilitySnapshot = "dockVisibilitySnapshot"
    }

    private let defaults = UserDefaults.standard

    var targetDisplayID: CGDirectDisplayID? {
        get {
            let value = defaults.integer(forKey: Key.targetDisplayID)
            return value > 0 ? CGDirectDisplayID(value) : nil
        }
        set {
            if let newValue {
                defaults.set(Int(newValue), forKey: Key.targetDisplayID)
            } else {
                defaults.removeObject(forKey: Key.targetDisplayID)
            }
        }
    }

    var dockVisibilitySnapshot: DockVisibilitySnapshot? {
        get {
            guard let data = defaults.data(forKey: Key.dockVisibilitySnapshot) else {
                return nil
            }
            return try? JSONDecoder().decode(DockVisibilitySnapshot.self, from: data)
        }
        set {
            if let newValue, let data = try? JSONEncoder().encode(newValue) {
                defaults.set(data, forKey: Key.dockVisibilitySnapshot)
            } else {
                defaults.removeObject(forKey: Key.dockVisibilitySnapshot)
            }
            defaults.synchronize()
        }
    }
}
