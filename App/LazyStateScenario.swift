import LazyState
import SwiftUI

/// Point-Free's `@LazyState`, as their README spells it: the creation runs
/// once, so the discarded allocations are gone — and the model is still the
/// one built from the first input.
struct LazyStateChild: View {
    @LazyState private var model: Model

    init(input: Int) {
        _model = LazyState { Model(input: input) }
    }

    var body: some View {
        ModelRow(model: model)
    }
}

#Preview("LazyState") {
    ParentView { LazyStateChild(input: $0) }
}
