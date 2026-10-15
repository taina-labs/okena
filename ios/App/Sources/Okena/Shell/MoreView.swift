import SwiftUI

/// The long tail of the web sidebar: everything that does not earn a tab of
/// its own. Each row is a `RowCard`, so the shell reads like the screens it
/// opens rather than like a system list.
struct MoreView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Space.space3) {
                row("Moradores", "person.2") {
                    MembersView()
                }
                row("Armazenamento", "externaldrive") {
                    StorageView()
                }
                row("Saúde", "waveform.path.ecg") {
                    SaudeView()
                }
                row("Pedidos de acesso", "tray.full") {
                    RequestsView()
                }
                row("Conta", "person.crop.circle") {
                    AccountView()
                }
            }
            .padding(Theme.Space.space4)
        }
        .background(Theme.Palette.bgApp)
        .navigationTitle("Mais")
    }

    private func row<Destination: View>(
        _ title: String,
        _ systemImage: String,
        @ViewBuilder destination: () -> Destination
    ) -> some View {
        NavigationLink {
            destination()
        } label: {
            RowCard {
                HStack(spacing: Theme.Space.space3) {
                    Image(systemName: systemImage)
                        .foregroundStyle(Theme.Palette.textMuted)
                        .frame(width: 24)
                    Text(title)
                        .typeStyle(Theme.Text.body)
                        .foregroundStyle(Theme.Palette.textPrimary)
                    Spacer(minLength: Theme.Space.space2)
                    Image(systemName: "chevron.right")
                        .typeStyle(Theme.Text.caption)
                        .foregroundStyle(Theme.Palette.textFaint)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

#if DEBUG
#Preview("Mais") {
    PreviewHost(make: { await SessionModel.previewSignedIn() }) { session in
        NavigationStack {
            MoreView()
        }
        .environment(session)
    }
}
#endif
