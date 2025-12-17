#if canImport(SwiftUI)
import SwiftUI
import Library

@main
struct NewPlayerApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}
#else
// SwiftUI not available; placeholder main for non-Apple platforms.
@main
struct NewPlayerCLI {
    static func main() {
        print("NewPlayer app stubs are available for Apple platforms.")
    }
}
#endif
