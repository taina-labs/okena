import OkenaCore
import SwiftUI
import UIKit

/// The invite accept, the native mirror of the web's `InviteAcceptLive`: the
/// token is checked lightly on arrival, a dead link shows the dead end
/// instead of the form, and the real validation stays on the submit. The
/// two password fields are the app's own check; the wire carries one.
struct InviteAcceptView: View {
    let pending: SessionModel.PendingAuth

    @Environment(SessionModel.self) private var session

    @State private var username = ""
    @State private var displayName = ""
    @State private var password = ""
    @State private var confirmation = ""
    @State private var mismatch: String?
    @State private var creating = false
    @State private var failure: TainaError?

    private enum Gate {
        case checking
        case open
        case dead
        case broken(TainaError)
    }

    @State private var gate: Gate = .checking

    var body: some View {
        Group {
            switch gate {
            case .checking:
                LoadingView()
            case .dead:
                deadEnd
            case .broken(let error):
                ErrorView(error: error, retry: { await check() })
            case .open:
                form
            }
        }
        .background(Theme.Palette.bgApp)
        .navigationTitle("Aceitar convite")
        .task { await check() }
    }

    /// The dead end of a token spent or expired: an honest sentence and the
    /// way back to the login.
    private var deadEnd: some View {
        EmptyStateView(
            systemImage: "clock",
            title: "Este convite expirou ou já foi usado",
            message: "Peça um novo link a quem te convidou.",
            action: EmptyStateAction(title: "Ir para o login") {
                Task { await session.leavePendingAuth() }
            }
        )
    }

    private var form: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Space.space5) {
                header
                title
                TainaField(
                    label: "Seu nome de usuário",
                    text: $username,
                    errorMessages: Self.fieldErrors(["username"], in: failure),
                    contentType: .username
                )
                TainaField(
                    label: "Nome de exibição (opcional)",
                    text: $displayName,
                    errorMessages: Self.fieldErrors(["display_name"], in: failure),
                    autocapitalization: .sentences,
                    contentType: .name
                )
                TainaField(
                    label: "Senha",
                    text: $password,
                    secure: true,
                    errorMessages: Self.fieldErrors(["password"], in: failure),
                    contentType: .newPassword
                )
                TainaField(
                    label: "Confirme a senha",
                    text: $confirmation,
                    secure: true,
                    errorMessages: mismatch.map { [$0] } ?? Self.fieldErrors(["password"], in: failure),
                    contentType: .newPassword
                )
                if let formMessage {
                    Text(formMessage)
                        .typeStyle(Theme.Text.bodySm)
                        .foregroundStyle(Theme.Palette.feedbackError)
                }
                PrimaryButton(title: "Criar conta", loading: creating) {
                    Task { await createAccount() }
                }
            }
            .padding(Theme.Space.space5)
        }
    }

    /// The community the link belongs to, always visible at the top, with
    /// the cleartext caveat where it applies.
    private var header: some View {
        VStack(alignment: .leading, spacing: Theme.Space.space2) {
            if let name = session.instance?.tekoa?.name {
                Text(name)
                    .typeStyle(Theme.Text.h2)
                    .foregroundStyle(Theme.Palette.textPrimary)
            }
            if let host = session.host {
                Text(host.display)
                    .typeStyle(Theme.Text.monoSm)
                    .foregroundStyle(Theme.Palette.textMuted)
                if host.isCleartext {
                    CleartextNotice()
                }
            }
        }
    }

    private var title: some View {
        VStack(spacing: Theme.Space.space2) {
            Image(systemName: "sparkles")
                .typeStyle(Theme.Text.display)
                .foregroundStyle(Theme.Palette.brandPrimary)
            Text("Você foi convidado!")
                .typeStyle(Theme.Text.h1)
                .foregroundStyle(Theme.Palette.textPrimary)
            Text("Crie sua conta para entrar na nuvem da comunidade.")
                .typeStyle(Theme.Text.body)
                .foregroundStyle(Theme.Palette.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    private var formMessage: String? {
        failure?.errorDescription
    }

    private func check() async {
        gate = .checking
        switch await session.checkToken(pending) {
        case .success(true):
            gate = .open
        case .success(false):
            gate = .dead
        case .failure(.api(let error)) where error.isUnauthorized:
            gate = .dead
        case .failure(let error):
            gate = .broken(error)
        }
    }

    private func createAccount() async {
        failure = nil
        guard Self.confirmationMatches(password: password, confirmation: confirmation) else {
            mismatch = "As duas senhas não são iguais."
            return
        }
        mismatch = nil
        creating = true
        let name = displayName.trimmingCharacters(in: .whitespaces)
        let result = await session.acceptInvite(
            token: pending.token,
            username: username.trimmingCharacters(in: .whitespaces),
            password: password,
            displayName: name.isEmpty ? nil : name,
            deviceName: UIDevice.current.name
        )
        if case .failure(let error) = result {
            failure = error
        }
        creating = false
    }

    /// The local rule the wire does not carry: the two passwords must
    /// match. Pure, so both screens say it the same way.
    private static func confirmationMatches(password: String, confirmation: String) -> Bool {
        password == confirmation
    }

    /// The messages of the field, in the wire spellings of the envelope.
    private static func fieldErrors(_ fields: [String], in failure: TainaError?) -> [String] {
        guard case .api(let error) = failure else { return [] }
        for field in fields {
            if let messages = error.details[field], !messages.isEmpty {
                return messages
            }
        }
        return []
    }
}

#if DEBUG
#Preview("Aceitar convite") {
    PreviewHost(make: { await SessionModel.previewPendingInvite() }) { seed in
        InviteAcceptView(pending: seed.pending)
            .environment(seed.model)
    }
}

#Preview("Convite expirado") {
    PreviewHost(make: { await SessionModel.previewPendingInvite(expired: true) }) { seed in
        InviteAcceptView(pending: seed.pending)
            .environment(seed.model)
    }
}
#endif
