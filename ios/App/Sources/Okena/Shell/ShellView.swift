import SwiftUI

/// The authenticated shell. The same destinations as the web navigation,
/// laid out for the phone: Início, Arquivos, Fotos and Mural earn a tab, and
/// the rest of the sidebar (Moradores, Armazenamento, Saúde, Pedidos and
/// Conta) lives under Mais, where a long tail belongs.
struct ShellView: View {
    var body: some View {
        TabView {
            Tab("Início", systemImage: "house") {
                NavigationStack {
                    HomeView()
                }
            }
            Tab("Arquivos", systemImage: "folder") {
                NavigationStack {
                    FilesView()
                }
            }
            Tab("Fotos", systemImage: "photo.on.rectangle") {
                NavigationStack {
                    GalleryView()
                }
            }
            Tab("Mural", systemImage: "list.bullet.rectangle") {
                NavigationStack {
                    MuralView()
                }
            }
            Tab("Mais", systemImage: "ellipsis") {
                NavigationStack {
                    MoreView()
                }
            }
        }
    }
}
