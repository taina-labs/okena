import SwiftUI

/// The switch on the session: the three states before the app, and the
/// authenticated shell after it.
struct RootView: View {
    @Environment(SessionModel.self) private var session

    var body: some View {
        switch session.state {
        case .checking:
            LoadingView()
                .background(Theme.Palette.bgApp)
        case .needsInstance:
            SetupView()
        case .needsLogin:
            LoginView()
        case .ready:
            ShellView()
                .background(Theme.Palette.bgApp)
        }
    }
}
