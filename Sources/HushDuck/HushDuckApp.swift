import SwiftUI

@main
struct HushDuckApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // No window — this is a menu bar-only app.
        // Settings scene prevents SwiftUI from requiring a WindowGroup.
        Settings {
            EmptyView()
        }
    }
}
