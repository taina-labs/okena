import SwiftUI

#if DEBUG
/// Renders the real screen once its preview model is ready: the preview
/// seams talk to the fake and are async, so the host shows the loading
/// state for a beat and then the screen in its real state.
struct PreviewHost<Payload, Content: View>: View {
    let make: () async -> Payload
    @ViewBuilder let content: (Payload) -> Content

    @State private var payload: Payload?

    var body: some View {
        switch payload {
        case .some(let value):
            content(value)
        case .none:
            LoadingView()
                .task { payload = await make() }
        }
    }
}
#endif
