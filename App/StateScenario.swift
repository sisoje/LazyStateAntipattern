import SwiftUI

/// Apple's `@State`, the model built in `init` from the parent's input —
/// the pattern `State.init(wrappedValue:)` documents as not to be written.
/// A model per parent render, and the first one is the one kept: stale.
struct StateChild: View {
    @State private var model: Model

    init(input: Int) {
        _model = State(wrappedValue: Model(input: input))
    }

    var body: some View {
        ModelRow(model: model)
    }
}

#Preview("State") {
    Parent { StateChild(input: $0) }
}
