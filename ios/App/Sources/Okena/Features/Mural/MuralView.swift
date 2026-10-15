import OkenaCore
import SwiftUI

/// The mural: the community's ledger, newest first, in plain words.
/// Read-only for every papel: the register of what happened, not a place
/// to act. Mirrors the web's MuralLive.
struct MuralView: View {
    @Environment(SessionModel.self) private var session
    @State private var model: MuralModel?

    var body: some View {
        Group {
            if let model {
                MuralList(model: model)
            } else {
                LoadingView()
            }
        }
        .navigationTitle("Mural")
        .task {
            if model == nil {
                model = MuralModel(api: session.api, session: session)
            }
        }
    }
}

/// The list: the ledger's promise in words, one line per act, and the
/// sentinel that walks the pages.
private struct MuralList: View {
    let model: MuralModel

    var body: some View {
        Group {
            if model.entries.isEmpty {
                if model.loading {
                    LoadingView()
                } else if let error = model.error {
                    ErrorView(error: error, retry: { await model.load() })
                } else {
                    EmptyStateView(
                        systemImage: "book",
                        title: "Nada aconteceu ainda",
                        message: "Quando alguém convidar, publicar na praça ou pedir acesso, o registro aparece aqui. Ninguém edita e ninguém apaga: o mural é a memória do que aconteceu."
                    )
                }
            } else {
                list
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Theme.Palette.bgApp)
        // Loads on appear and on pull: the list owns its own loading.
        .task { await model.load() }
        .refreshable { await model.load() }
    }

    private var list: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: Theme.Space.space5) {
                Text("O que aconteceu na comunidade. Cada linha registra um ato: ninguém edita, ninguém apaga.")
                    .typeStyle(Theme.Text.bodySm)
                    .foregroundStyle(Theme.Palette.textMuted)
                ForEach(model.entries, id: \.cid) { entry in
                    MuralRow(sentence: model.sentence(for: entry), ago: Format.relative(entry.createdAt))
                }
                sentinel
            }
            .padding(Theme.Space.space4)
        }
    }

    /// The next page: a spinner that loads on sight, or the retry when a
    /// page failed. It only exists while the server still has rows.
    @ViewBuilder
    private var sentinel: some View {
        if model.nextCursor != nil {
            if model.moreError {
                VStack(spacing: Theme.Space.space2) {
                    Text("Não foi possível carregar mais do mural.")
                        .typeStyle(Theme.Text.caption)
                        .foregroundStyle(Theme.Palette.textMuted)
                    SecondaryButton(title: "Tentar de novo") {
                        Task { await model.loadMore() }
                    }
                }
                .frame(maxWidth: .infinity)
            } else {
                ProgressView()
                    .tint(Theme.Palette.textMuted)
                    .frame(maxWidth: .infinity)
                    .task { await model.loadMore() }
            }
        }
    }
}

/// One entry: the act in words, and when. The sentence is the web's own,
/// from the shared table; the chain's ids never reach the screen.
private struct MuralRow: View {
    let sentence: String
    let ago: String

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.space1) {
            Text(sentence)
                .typeStyle(Theme.Text.body)
                .foregroundStyle(Theme.Palette.textPrimary)
            Text(ago)
                .typeStyle(Theme.Text.caption)
                .foregroundStyle(Theme.Palette.textFaint)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#if DEBUG
#Preview("Mural") {
    PreviewHost(make: { await SessionModel.previewSignedIn() }) { session in
        MuralView()
            .environment(session)
    }
}
#endif
