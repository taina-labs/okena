import SwiftUI

/// The authenticated shell. The same destinations as the web navigation,
/// laid out for the phone: Início, Arquivos, Fotos and Mural earn a tab, and
/// the rest of the sidebar (Moradores, Armazenamento, Saúde, Pedidos and
/// Conta) lives under Mais, where a long tail belongs.
struct ShellView: View {
    @State private var selection = ShellView.initialTab()
    @State private var morePath = ShellView.initialMorePath()

    var body: some View {
        TabView(selection: $selection) {
            Tab("Início", systemImage: "house", value: ShellTab.inicio) {
                NavigationStack {
                    HomeView()
                }
            }
            Tab("Arquivos", systemImage: "folder", value: ShellTab.arquivos) {
                NavigationStack {
                    FilesView()
                }
            }
            Tab("Fotos", systemImage: "photo.on.rectangle", value: ShellTab.fotos) {
                NavigationStack {
                    GalleryView()
                }
            }
            Tab("Mural", systemImage: "list.bullet.rectangle", value: ShellTab.mural) {
                NavigationStack {
                    MuralView()
                }
            }
            Tab("Mais", systemImage: "ellipsis", value: ShellTab.mais) {
                NavigationStack(path: $morePath) {
                    MoreView()
                }
            }
        }
    }

    /// The tab the app opens on. In DEBUG, `TAINA_TAB` picks it, the same way
    /// `TAINA_HOST` drives the setup flow: it lets a script or a UI test land
    /// on a screen without tapping. The running app opens on Início.
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

enum ShellTab: String {
    case inicio, arquivos, fotos, mural, mais
}

/// The rows of Mais, as navigation values so the shell owns the stack.
enum MoreRoute: String, Hashable {
    case moradores, armazenamento, saude, pedidos, conta
}
