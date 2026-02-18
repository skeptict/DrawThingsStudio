import XCTest

/// Shared app proxy — launched exactly once for the entire UI test suite.
/// All test classes reference `SharedApp.app` instead of creating their own XCUIApplication.
enum SharedApp {
    static let app = XCUIApplication()
    private static var launched = false

    /// Call from every class's `override class func setUp()`.
    /// Launches the app only on the first call; all subsequent calls are no-ops.
    static func launchOnce() {
        guard !launched else { return }
        launched = true
        app.launchEnvironment["UI_TESTING"] = "1"
        app.launch()
    }
}
