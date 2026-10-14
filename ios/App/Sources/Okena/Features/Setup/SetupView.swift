import OkenaCore
import SwiftUI

/// The first screen: the address of the community's box. One field, one
/// button, and an honest answer for every outcome.
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
                    ErrorView(error: failure, retry: { await connect() })
                }
            }
            .padding(Theme.Space.space5)
        }
        .background(Theme.Palette.bgApp)
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
