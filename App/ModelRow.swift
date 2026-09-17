import SwiftUI

/// What every child shows, whatever built its model.
struct ModelRow: View {
    let model: Model

    var body: some View {
        Text(verbatim: "model input \(model.input)")
        Text(verbatim: "models created \(Model.creations.count)")
    }
}
