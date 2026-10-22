import SwiftUI

/// The shell's navigation state, in the environment so a screen can land
/// the person elsewhere in the shell: the home's rows open a tab or a Mais
/// row directly, not only through the tab bar.
@MainActor
@Observable
final class ShellModel {
    var selection: ShellTab
    var morePath: [MoreRoute]

    init() {
        selection = Self.initialTab()
        morePath = Self.initialMorePath()
    }

    /// Opens one of the shell's tabs.
    func open(_ tab: ShellTab) {
        selection = tab
    }

    /// Opens a Mais row in one gesture: the tab and the route together, so
    /// the destination is on screen, not one tap behind.
    func open(_ route: MoreRoute) {
        selection = .mais
        morePath = [route]
    }

    /// The tab the app opens on. In DEBUG, `TAINA_TAB` picks it, the same
    /// way `TAINA_HOST` drives the setup flow: it lets a script or a UI
    /// test land on a screen without tapping. The running app opens on
    /// Início.
    private static func initialTab() -> ShellTab {
        #if DEBUG
        if let raw = ProcessInfo.processInfo.environment["TAINA_TAB"],
           let tab = ShellTab(rawValue: raw) {
            return tab
        }
        #endif
        return .inicio
    }

    /// The same seam for the Mais rows: `TAINA_MORE` opens one of them on
    /// launch. The running app opens on the Mais list itself.
    private static func initialMorePath() -> [MoreRoute] {
        #if DEBUG
        if let raw = ProcessInfo.processInfo.environment["TAINA_MORE"],
           let route = MoreRoute(rawValue: raw) {
            return [route]
        }
        #endif
        return []
    }
}
