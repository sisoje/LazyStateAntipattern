import SwiftUI

/// A Memo keyed by the input: built when the input is new, kept otherwise.
/// Nothing is seeded into state, so there is nothing to go stale.
struct MemoChild: View {
    let input: Int

    var body: some View {
        MemoView(Model(input: input), dependencies: [input]) { model in
            ModelRow(model: model)
        }
    }
}

#Preview("Memo") {
    Parent { MemoChild(input: $0) }
}
