import SwiftUI

/// The switch on the session: the three states before the app, and the two
/// tabs after it, each in its own stack.
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
            TabView {
                Tab("Arquivos", systemImage: "folder") {
                    NavigationStack {
                        FilesView()
                    }
                }
                Tab("Conta", systemImage: "person") {
                    NavigationStack {
                        AccountView()
                    }
                }
            }
            .background(Theme.Palette.bgApp)
        }
    }
}
