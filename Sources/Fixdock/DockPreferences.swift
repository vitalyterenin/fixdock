import Foundation

final class DockPreferences {
    private let dockDefaults = UserDefaults(suiteName: "com.apple.dock")

    var currentEdge: DockEdge {
        DockEdge.fromDockPreference(dockDefaults?.string(forKey: "orientation"))
    }
}
