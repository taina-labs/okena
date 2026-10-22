import SwiftUI

/// The authenticated shell. The same destinations as the web navigation,
/// laid out for the phone: Início, Arquivos, Fotos and Mural earn a tab, and
/// the rest of the sidebar (Moradores, Armazenamento, Saúde, Pedidos and
/// Conta) lives under Mais, where a long tail belongs. The navigation state
/// is a `ShellModel` in the environment, so the screens can move the person
/// across tabs (the home's rows do). MainActor like the `SessionModel` it
/// shares state with: the view's `@State` default builds one in isolation.
@MainActor
struct ShellView: View {
    @State private var shell = ShellModel()

    var body: some View {
        TabView(selection: $shell.selection) {
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
                NavigationStack(path: $shell.morePath) {
                    MoreView()
                }
            }
        }
        .environment(shell)
    }
}

enum ShellTab: String {
    case inicio, arquivos, fotos, mural, mais
}

/// The rows of Mais, as navigation values so the shell owns the stack.
enum MoreRoute: String, Hashable {
    case moradores, armazenamento, saude, pedidos, conta
}
