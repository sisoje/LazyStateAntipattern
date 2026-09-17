import SwiftUI

/// One screen, three scenarios: the UI test picks one per launch, and each
/// scenario file carries its own `#Preview`.
@main
struct TrapApp: App {
    private let scenario = ProcessInfo.processInfo.environment["SCENARIO"]

    var body: some Scene {
        WindowGroup {
            switch scenario {
            case "state": Parent { StateChild(input: $0) }
            case "lazyState": Parent { LazyStateChild(input: $0) }
            default: Parent { MemoChild(input: $0) }
            }
        }
    }
}
