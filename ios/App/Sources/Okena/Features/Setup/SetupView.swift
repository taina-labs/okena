import OkenaCore
import SwiftUI

/// The first screen: the address of the community's box, and the invite
/// link for the person who arrived with one. One address field, one
/// button, one paste field, and an honest answer for every outcome.
struct SetupView: View {
    @Environment(SessionModel.self) private var session

    @State private var input: String
    @State private var probing = false
    @State private var failure: TainaError?

    /// The address the preview starts with; the app starts empty.
    init(address: String = "") {
        _input = State(initialValue: address)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Space.space5) {
                VStack(alignment: .leading, spacing: Theme.Space.space2) {
                    Text("Sua comunidade")
                        .typeStyle(Theme.Text.h1)
                        .foregroundStyle(Theme.Palette.textPrimary)
                    Text("Tainá guarda os arquivos da sua comunidade numa caixa só dela. Digite o endereço dessa caixa: quem instalou passou um endereço parecido com taina.minhacasa.ts.net.")
                        .typeStyle(Theme.Text.body)
                        .foregroundStyle(Theme.Palette.textSecondary)
                }
                TainaField(
                    label: "Endereço da comunidade",
                    text: $input,
                    keyboard: .URL,
                    contentType: .URL
                )
                PrimaryButton(title: "Conectar", loading: probing) {
                    Task { await connect() }
                }
                if typedCleartext {
                    CleartextNotice()
                }
                if let instance = session.instance, !instance.bootstrapped {
                    RowCard {
                        VStack(alignment: .leading, spacing: Theme.Space.space2) {
                            Text("A comunidade ainda não foi criada")
                                .typeStyle(Theme.Text.label)
                                .foregroundStyle(Theme.Palette.feedbackWarning)
                            Text("Este endereço respondeu, mas ninguém criou a comunidade nele ainda. Confira o endereço com quem instalou a caixa.")
                                .typeStyle(Theme.Text.bodySm)
                                .foregroundStyle(Theme.Palette.textSecondary)
                        }
                    }
                }
                if let failure {
                    if Self.unreachable(failure) {
                        unreachableCard
                    } else {
                        ErrorView(error: failure, retry: { await connect() })
                    }
                }
                InvitePasteField()
            }
            .padding(Theme.Space.space5)
        }
        .background(Theme.Palette.bgApp)
    }

    /// Says so while the person types, not after a failed attempt: the vault
    /// deserves to know the path it is about to use.
    private var typedCleartext: Bool {
        guard case .success(let address) = InstanceAddress.parse(input: input) else {
            return false
        }
        return address.isCleartext
    }

    /// Nothing answered at this address, on either scheme: the one
    /// failure where the person can act, so it names what to check
    /// instead of the generic "verifique a conexão".
    private static func unreachable(_ error: TainaError) -> Bool {
        if case .network = error { return true }
        return false
    }

    private static let unreachableMessage =
        "Nada respondeu neste endereço. Confira se ele está certo, se a caixa está ligada e se este aparelho está na rede da comunidade."

    private var unreachableCard: some View {
        VStack(spacing: Theme.Space.space4) {
            Image(systemName: "exclamationmark.triangle")
                .typeStyle(Theme.Text.h2)
                .foregroundStyle(Theme.Palette.feedbackWarning)
            Text(Self.unreachableMessage)
                .typeStyle(Theme.Text.body)
                .foregroundStyle(Theme.Palette.textSecondary)
                .multilineTextAlignment(.center)
            SecondaryButton(title: "Tentar de novo") {
                Task { await connect() }
            }
        }
        .padding(Theme.Space.space5)
        .frame(maxWidth: .infinity)
    }

    private func connect() async {
        probing = true
        failure = nil
        switch await session.connect(input) {
        case .success:
            // A bootstrapped community already moved the app to the login;
            // a box without a community stays here, with the card above.
            if session.instance?.bootstrapped != true {
                probing = false
            }
        case .failure(let error):
            failure = error
            probing = false
        }
    }
}

#if DEBUG
#Preview("Setup, nothing typed") {
    SetupView()
        .environment(SessionModel.previewSetup())
}

#Preview("Setup, typed address") {
    SetupView(address: "taina.minhacasa.ts.net")
        .environment(SessionModel.previewSetup())
}
#endif
