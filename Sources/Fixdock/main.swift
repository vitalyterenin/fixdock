import AppKit

if CommandLine.arguments.contains("--diagnostics") {
    let info = Bundle.main.infoDictionary ?? [:]
    print("Fixdock \(info["CFBundleShortVersionString"] ?? "development") (build \(info["CFBundleVersion"] ?? "unknown"))")
    print("Bundle: \(Bundle.main.bundleIdentifier ?? "unbundled")")
    exit(0)
}
let app = NSApplication.shared
let delegate = AppDelegate()
if CommandLine.arguments.contains("--smoke-test") {
    app.setActivationPolicy(.accessory)
    guard delegate.smokeTestMenu() else { fatalError("Menu structure validation failed") }
    print("Validated Dock selection and update menu; no Dock preferences or permissions changed")
    exit(0)
}
app.delegate = delegate
app.run()
