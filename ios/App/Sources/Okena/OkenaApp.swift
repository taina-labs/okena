import SwiftUI

@main
struct OkenaApp: App {
    @State private var session = SessionModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(session)
                .tint(Theme.Palette.brandPrimary)
                .task {
                    await session.restore()
                }
                .onOpenURL { url in
                    Task { await session.handleDeepLink(url) }
                }
        }
    }
}
