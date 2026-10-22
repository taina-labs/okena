import OkenaCore
import SwiftUI

/// The account: who is acting, which devices, which community, and the
/// way out. Signing out is a DELETE /session, so the dialog says the
/// aparelho loses access. The password is self-service: the box keeps
/// this aparelho signed in and revokes the others. The devices are the
/// account's own: each aparelho that is not this one can be revoked,
/// with a confirmation and the box's word on failure.
struct AccountView: View {
    @Environment(SessionModel.self) private var session

    @State private var confirming = false
    @State private var leaving = false
    @State private var devices: [DeviceToken]?
    @State private var devicesError: TainaError?
    @State private var confirmingRevoke: DeviceToken?
    @State private var revoking = false
    @State private var failure: TainaError?
    @State private var currentPassword = ""
    @State private var newPassword = ""
    @State private var confirmation = ""
    @State private var mismatch: String?
    @State private var changing = false
    @State private var changed = false
    @State private var passwordFailure: TainaError?

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
                section("Senha") {
                    passwordForm
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

    /// The self-service password change: the current one proves who is
    /// asking, the two new ones are the app's own check, and the box's
    /// answer lands as field messages or the success line.
    private var passwordForm: some View {
        RowCard {
            VStack(alignment: .leading, spacing: Theme.Space.space3) {
                TainaField(
                    label: "Senha atual",
                    text: $currentPassword,
                    secure: true,
                    errorMessages: passwordFailure?.messages(for: ["current_password"]) ?? [],
                    contentType: .password
                )
                TainaField(
                    label: "Senha nova",
                    text: $newPassword,
                    secure: true,
                    errorMessages: passwordFailure?.messages(for: ["new_password", "password"]) ?? [],
                    contentType: .newPassword,
                    placeholder: "mínimo 8 caracteres"
                )
                TainaField(
                    label: "Confirme a senha nova",
                    text: $confirmation,
                    secure: true,
                    errorMessages: mismatch.map { [$0] } ?? [],
                    contentType: .newPassword,
                    placeholder: "a mesma senha"
                )
                if let passwordFailure {
                    Text(passwordFailure.errorDescription ?? "Algo deu errado. Tente de novo.")
                        .typeStyle(Theme.Text.bodySm)
                        .foregroundStyle(Theme.Palette.feedbackError)
                }
                if changed {
                    Text("Senha trocada. Nos outros aparelhos, é preciso entrar de novo com a senha nova.")
                        .typeStyle(Theme.Text.bodySm)
                        .foregroundStyle(Theme.Palette.feedbackSuccess)
                }
                PrimaryButton(title: "Trocar minha senha", loading: changing) {
                    Task { await changePassword() }
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
                    VStack(alignment: .leading, spacing: Theme.Space.space1) {
                        Text("Identificação deste aparelho")
                            .typeStyle(Theme.Text.caption)
                            .foregroundStyle(Theme.Palette.textMuted)
                        Text(device.publicId)
                            .typeStyle(Theme.Text.monoSm)
                            .foregroundStyle(Theme.Palette.textMuted)
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .textSelection(.enabled)
                        Text("É assim que a comunidade distingue este aparelho dos outros.")
                            .typeStyle(Theme.Text.caption)
                            .foregroundStyle(Theme.Palette.textMuted)
                    }
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

    private func changePassword() async {
        passwordFailure = nil
        guard Self.confirmationMatches(password: newPassword, confirmation: confirmation) else {
            mismatch = "As duas senhas não são iguais."
            return
        }
        mismatch = nil
        changing = true
        let result = await session.updatePassword(current: currentPassword, new: newPassword)
        switch await session.screen(result) {
        case .success:
            changed = true
            currentPassword = ""
            newPassword = ""
            confirmation = ""
            // The other aparelhos were revoked on the box: the list says so.
            await loadDevices()
        case .failure(let error):
            passwordFailure = error
        }
        changing = false
    }

    /// The local rule the wire does not carry: the two passwords must
    /// match. Pure, so every screen says it the same way.
    private static func confirmationMatches(password: String, confirmation: String) -> Bool {
        password == confirmation
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
