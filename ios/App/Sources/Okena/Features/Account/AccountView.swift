import OkenaCore
import SwiftUI

/// The account: who is acting, which devices, which community, and the way
/// out. Signing out is a DELETE /session, so the dialog says the aparelho
/// loses access. The devices are the account's own: each aparelho that is
/// not this one can be revoked, with a confirmation and the box's word on
/// failure.
struct AccountView: View {
    @Environment(SessionModel.self) private var session

    @State private var confirming = false
    @State private var leaving = false
    @State private var devices: [DeviceToken]?
    @State private var devicesError: TainaError?
    @State private var confirmingRevoke: DeviceToken?
    @State private var revoking = false
    @State private var failure: TainaError?

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
        .task { await loadDevices() }
        .confirmationDialog("Sair da comunidade?", isPresented: $confirming, titleVisibility: .visible) {
            Button("Sair", role: .destructive) {
                Task { await leave() }
            }
            Button("Ficar", role: .cancel) {}
        } message: {
            Text("Ao sair, este aparelho perde o acesso à comunidade. Para voltar, entre de novo com o seu usuário e senha.")
        }
        .confirmationDialog(
            "Revogar o acesso deste aparelho?",
            isPresented: Binding(
                get: { confirmingRevoke != nil },
                set: { if !$0 { confirmingRevoke = nil } }
            ),
            titleVisibility: .visible,
            presenting: confirmingRevoke
        ) { device in
            Button("Revogar", role: .destructive) {
                Task { await revoke(device) }
            }
            Button("Cancelar", role: .cancel) {}
        } message: { device in
            Text("\"\(device.name)\" perde o acesso à comunidade. Para voltar, é preciso entrar de novo nele.")
        }
        .alert(
            "Não deu certo",
            isPresented: Binding(
                get: { failure != nil },
                set: { if !$0 { failure = nil } }
            ),
            presenting: failure
        ) { _ in
            Button("Entendi", role: .cancel) {}
        } message: { error in
            Text(error.errorDescription ?? "Algo deu errado. Tente de novo.")
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
                            if let username = me.ava.username {
                                Text("@\(username)")
                                    .typeStyle(Theme.Text.monoSm)
                                    .foregroundStyle(Theme.Palette.textMuted)
                            }
                            Text(me.ava.papel.label)
                                .typeStyle(Theme.Text.bodySm)
                                .foregroundStyle(Theme.Palette.textSecondary)
                        }
                    }
                }
                section("Aparelhos") {
                    devicesSection(current: me.device)
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
                                if host.isCleartext {
                                    CleartextNotice()
                                }
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

    @ViewBuilder
    private func devicesSection(current: DeviceToken?) -> some View {
        if let error = devicesError {
            ErrorView(error: error, retry: { await loadDevices() })
        } else if let devices {
            if devices.isEmpty {
                EmptyStateView(
                    systemImage: "iphone",
                    title: "Nenhum aparelho",
                    message: "Os aparelhos que entram na sua conta aparecem aqui."
                )
            } else {
                VStack(spacing: Theme.Space.space2) {
                    ForEach(devices, id: \.publicId) { device in
                        deviceRow(device, current: current)
                    }
                }
            }
        } else {
            RowCard {
                HStack {
                    ProgressView()
                        .tint(Theme.Palette.textMuted)
                    Spacer()
                }
            }
        }
    }

    private func deviceRow(_ device: DeviceToken, current: DeviceToken?) -> some View {
        RowCard {
            VStack(alignment: .leading, spacing: Theme.Space.space2) {
                HStack {
                    Text(device.name)
                        .typeStyle(Theme.Text.label)
                        .foregroundStyle(Theme.Palette.textPrimary)
                        .lineLimit(1)
                    Spacer()
                    if device.publicId == current?.publicId {
                        Text("Este aparelho")
                            .typeStyle(Theme.Text.caption)
                            .foregroundStyle(Theme.Palette.textSecondary)
                    }
                }
                Text(Self.deviceLine(device))
                    .typeStyle(Theme.Text.monoSm)
                    .foregroundStyle(device.revokedAt == nil ? Theme.Palette.textSecondary : Theme.Palette.textMuted)
                if device.publicId == current?.publicId {
                    Text(device.publicId)
                        .typeStyle(Theme.Text.monoSm)
                        .foregroundStyle(Theme.Palette.textMuted)
                        .textSelection(.enabled)
                }
                if device.revokedAt == nil, device.publicId != current?.publicId {
                    SecondaryButton(
                        title: "Revogar",
                        textColor: Theme.Palette.feedbackError
                    ) {
                        confirmingRevoke = device
                    }
                    .disabled(revoking)
                }
            }
        }
    }

    /// One line per aparelho: revoked when it is, the last use otherwise.
    private static func deviceLine(_ device: DeviceToken) -> String {
        if let revoked = device.revokedAt {
            return "Revogado em " + Format.date(revoked)
        }
        if let used = device.lastUsedAt {
            return "Último uso em " + Format.date(used)
        }
        return "Nunca usado"
    }

    private func section(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.space2) {
            Text(title)
                .typeStyle(Theme.Text.overline)
                .foregroundStyle(Theme.Palette.textMuted)
            content()
        }
    }

    private func loadDevices() async {
        let result = await session.api.devices()
        switch await session.screen(result) {
        case .success(let found):
            devices = found
            devicesError = nil
        case .failure(let error):
            // With a list already on screen, the failure is the alert, not
            // a replacement of the section.
            if devices == nil {
                devicesError = error
            } else {
                failure = error
            }
        }
    }

    private func revoke(_ device: DeviceToken) async {
        revoking = true
        failure = nil
        let result = await session.api.revokeDevice(id: device.publicId)
        switch await session.screen(result) {
        case .success:
            await loadDevices()
        case .failure(let error):
            failure = error
        }
        revoking = false
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
