import CoreGraphics
import Foundation

final class SettingsStore {
    private enum Key {
        static let targetDisplayID = "targetDisplayID"
        static let oldDefaultsSuiteName = "local.vitalyterenin.DockAnchor"
        static let obsoleteKeys = [
            "isPaused",
            "hasPromptedForAccessibility",
            "showsEdgeShields"
        ]
    }

    private let defaults = UserDefaults.standard

    init() {
        migrateFromDockAnchorDefaultsIfNeeded()

        for key in Key.obsoleteKeys {
            defaults.removeObject(forKey: key)
        }
    }

    private func migrateFromDockAnchorDefaultsIfNeeded() {
        guard
            defaults.object(forKey: Key.targetDisplayID) == nil,
            let oldDefaults = UserDefaults(suiteName: Key.oldDefaultsSuiteName)
        else {
            return
        }

        let oldDisplayID = oldDefaults.integer(forKey: Key.targetDisplayID)
        if oldDisplayID > 0 {
            defaults.set(oldDisplayID, forKey: Key.targetDisplayID)
        }
    }

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
