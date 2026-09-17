import SwiftUI

/// The same parent for every scenario. It owns the input it hands to the
/// child, and a counter the child never sees.
struct ParentView<Child: View>: View {
    @ViewBuilder let child: (Int) -> Child
    @State private var input = 1
    @State private var unrelated = 0

    var body: some View {
        VStack(spacing: 16) {
            Button("related action") { input += 1 }
            Text(verbatim: "parent input \(input)")
            Button("unrelated action") { unrelated += 1 }
            Text(verbatim: "unrelated counter \(unrelated)")
            Divider()
            child(input)
        }
        .padding()
    }
}
