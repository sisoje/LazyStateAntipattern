import Observation
import SwiftUI

/// How many models have been created. Observable, not a plain `static var`:
/// in the `@State` scenario the kept model is the same instance on every
/// render, so `ModelRow` compares equal and SwiftUI skips its body — a plain
/// static read there is never re-read, and the row sits at the count it saw
/// at launch (measured: it showed 1 while three models had been built).
/// Observation is what invalidates the row when the count changes.
@Observable
final class Creations {
    private(set) var count = 0
    @ObservationIgnored private var raw = 0

    /// A write with no observed read: `count += 1` would READ `count` inside
    /// whatever body is creating the model, subscribe that body to it, and
    /// re-render it forever.
    func increment() {
        raw += 1
        count = raw
    }
}

/// Built from the parent's input.
@Observable
final class Model {
    /// Counted in `init` below, so every creation shows up on screen.
    static let creations = Creations()

    let input: Int

    init(input: Int) {
        self.input = input
        Model.creations.increment()
    }
}

/// What every child shows, whatever built its model.
struct ModelRow: View {
    let model: Model

    var body: some View {
        Text(verbatim: "model input \(model.input)")
        Text(verbatim: "models created \(Model.creations.count)")
    }
}
