import CoreGraphics
import Foundation

final class SettingsStore {
    private enum Key {
        static let targetDisplayID = "targetDisplayID"
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
}
