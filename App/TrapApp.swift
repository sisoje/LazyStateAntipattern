import SwiftUI

/// One screen, three scenarios: the UI test picks one per launch, and each
/// scenario file carries its own `#Preview`.
@main
struct TrapApp: App {
    private let scenario = ProcessInfo.processInfo.environment["SCENARIO"]

    var body: some Scene {
        WindowGroup {
            switch scenario {
            case "state": ParentView { StateChild(input: $0) }
            case "lazyState": ParentView { LazyStateChild(input: $0) }
            // "memo", and a plain launch with no scenario set.
            default: ParentView { MemoChild(input: $0) }
            }
        }
    }
}
