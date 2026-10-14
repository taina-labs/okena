import OkenaCore
import SwiftUI

/// The account: who is acting, which device, which community, and the way
/// out. Signing out is a DELETE /session, so the dialog says the aparelho
/// loses access.
struct AccountView: View {
    @Environment(SessionModel.self) private var session

    @State private var confirming = false
    @State private var leaving = false

    var body: some View {
        Group {
            if case .ready(let me) = session.state {
                content(me)
            } else {
                LoadingView()
            }
        }
        .background(Theme.Palette.bgApp)
        .navigationTitle("Conta")
        .task { await session.probe() }
        .confirmationDialog("Sair da comunidade?", isPresented: $confirming, titleVisibility: .visible) {
            Button("Sair", role: .destructive) {
                Task { await leave() }
            }
            Button("Ficar", role: .cancel) {}
        } message: {
            Text("Ao sair, este aparelho perde o acesso à comunidade. Para voltar, entre de novo com o seu usuário e senha.")
        }
    }

    private func content(_ me: Me) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Space.space5) {
                section("Você") {
                    RowCard {
                        VStack(alignment: .leading, spacing: Theme.Space.space2) {
                            Text(me.ava.label)
                                .typeStyle(Theme.Text.h3)
                                .foregroundStyle(Theme.Palette.textPrimary)
                            Text("@\(me.ava.username)")
                                .typeStyle(Theme.Text.monoSm)
                                .foregroundStyle(Theme.Palette.textMuted)
                            Text(me.ava.papel.label)
                                .typeStyle(Theme.Text.bodySm)
                                .foregroundStyle(Theme.Palette.textSecondary)
                        }
                    }
                }
                if let device = me.device {
                    section("Aparelho") {
                        RowCard {
                            VStack(alignment: .leading, spacing: Theme.Space.space2) {
                                Text(device.name)
                                    .typeStyle(Theme.Text.label)
                                    .foregroundStyle(Theme.Palette.textPrimary)
                                Text(device.publicId)
                                    .typeStyle(Theme.Text.monoSm)
                                    .foregroundStyle(Theme.Palette.textMuted)
                                    .textSelection(.enabled)
                            }
                        }
                    }
                }
                section("Comunidade") {
                    RowCard {
                        VStack(alignment: .leading, spacing: Theme.Space.space2) {
                            Text(me.tekoa.name)
                                .typeStyle(Theme.Text.label)
                                .foregroundStyle(Theme.Palette.textPrimary)
                            if let host = session.host {
                                Text(host.display)
                                    .typeStyle(Theme.Text.monoSm)
                                    .foregroundStyle(Theme.Palette.textMuted)
                            }
                            if let version = session.instance?.version {
                                Text("Versão da caixa: \(version)")
                                    .typeStyle(Theme.Text.bodySm)
                                    .foregroundStyle(Theme.Palette.textSecondary)
                            }
                        }
                    }
                }
                if let quota = me.tekoa.storageQuotaBytes {
                    section("Espaço") {
                        RowCard {
                            VStack(alignment: .leading, spacing: Theme.Space.space2) {
                                Text("\(Format.bytes(me.tekoa.storageUsedBytes)) de \(Format.bytes(quota))")
                                    .typeStyle(Theme.Text.monoSm)
                                    .foregroundStyle(Theme.Palette.textPrimary)
                                ProgressView(value: Double(me.tekoa.storageUsedBytes) / Double(quota))
                                    .tint(Theme.Palette.serviceYbira)
                            }
                        }
                    }
                }
                Button {
                    confirming = true
                } label: {
                    Text(leaving ? "Saindo..." : "Sair da comunidade")
                }
                .buttonStyle(SecondaryButtonStyle(textColor: Theme.Palette.feedbackError))
                .disabled(leaving)
            }
            .padding(Theme.Space.space5)
        }
    }

    private func section(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.space2) {
            Text(title)
                .typeStyle(Theme.Text.overline)
                .foregroundStyle(Theme.Palette.textMuted)
            content()
        }
    }

    private func leave() async {
        leaving = true
        await session.signOut()
        // The state change swaps this screen for the login.
        leaving = false
    }
}

#if DEBUG
#Preview("Conta") {
    PreviewHost(make: { await SessionModel.previewSignedIn() }) { session in
        AccountView()
            .environment(session)
    }
}
#endif
