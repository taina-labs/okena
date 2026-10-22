import OkenaCore
import SwiftUI
import UIKit

/// The sign in: username, password, device name, and the community the
/// person is entering, always visible at the top. The invite link pasted
/// at the bottom goes through the deep-link path, for the person whose
/// way in is a link, not a password.
struct LoginView: View {
    @Environment(SessionModel.self) private var session

    @State private var username = ""
    @State private var password = ""
    @State private var deviceName = UIDevice.current.name
    @State private var signingIn = false
    @State private var failure: TainaError?

    /// The failure the preview starts with; the app starts clean.
    init(failure: TainaError? = nil) {
        _failure = State(initialValue: failure)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Space.space5) {
                header
                TainaField(
                    label: "Usuário",
                    text: $username,
                    errorMessages: failure?.messages(for: ["username"]) ?? [],
                    contentType: .username,
                    placeholder: "seu nome de usuário"
                )
                TainaField(
                    label: "Senha",
                    text: $password,
                    secure: true,
                    errorMessages: failure?.messages(for: ["password"]) ?? [],
                    contentType: .password,
                    placeholder: "sua senha"
                )
                TainaField(
                    label: "Nome deste aparelho",
                    text: $deviceName,
                    errorMessages: failure?.messages(for: ["device_name", "deviceName"]) ?? [],
                    autocapitalization: .sentences
                )
                if let formMessage {
                    Text(formMessage)
                        .typeStyle(Theme.Text.bodySm)
                        .foregroundStyle(Theme.Palette.feedbackError)
                }
                PrimaryButton(title: "Entrar", loading: signingIn) {
                    Task { await enter() }
                }
                InvitePasteField()
            }
            .padding(Theme.Space.space5)
        }
        .background(Theme.Palette.bgApp)
        .navigationTitle("Entrar")
        .task { await session.probe() }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: Theme.Space.space2) {
            if let notice = session.notice {
                Text(notice)
                    .typeStyle(Theme.Text.bodySm)
                    .foregroundStyle(Theme.Palette.feedbackWarning)
                    .padding(Theme.Space.space3)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Theme.Palette.surfaceRaised, in: RoundedRectangle(cornerRadius: Theme.Radius.md))
            }
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
            Text("Entre com o seu usuário e senha da comunidade.")
                .typeStyle(Theme.Text.body)
                .foregroundStyle(Theme.Palette.textSecondary)
        }
    }

    private var formMessage: String? {
        guard let failure else { return nil }
        return Self.formMessage(for: failure)
    }

    private func enter() async {
        signingIn = true
        failure = nil
        let name = deviceName.trimmingCharacters(in: .whitespaces)
        let result = await session.login(
            username: username.trimmingCharacters(in: .whitespaces),
            password: password,
            deviceName: name.isEmpty ? UIDevice.current.name : name
        )
        if case .failure(let error) = result {
            failure = error
        }
        signingIn = false
    }

    /// The sentence above the button: the rate limit explains itself; the
    /// rest is the error's own pt-BR description.
    private static func formMessage(for failure: TainaError) -> String? {
        if case .api(let error) = failure, error.isRateLimited {
            return "Muitas tentativas de entrada. Espere um pouco antes de tentar de novo."
        }
        return failure.errorDescription
    }
}

#if DEBUG
#Preview("Login") {
    PreviewHost(make: { await SessionModel.previewLogin() }) { session in
        LoginView()
            .environment(session)
    }
}

#Preview("Login, field error") {
    PreviewHost(make: { await SessionModel.previewLoginFieldError() }) { seed in
        LoginView(failure: seed.failure)
            .environment(seed.model)
    }
}
#endif
