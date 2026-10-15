import OkenaCore
import SwiftUI

/// The lixeira: what was discarded in the last 30 days, with restore.
/// Mirrors the web's TrashLive, retention line and all.
struct TrashView: View {
    @Environment(SessionModel.self) private var session
    @State private var model: TrashModel?

    var body: some View {
        Group {
            if let model {
                TrashList(model: model)
            } else {
                LoadingView()
            }
        }
        .navigationTitle("Lixeira")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if model == nil {
                model = TrashModel(api: session.api, session: session)
            }
        }
    }
}

/// The list: the retention rule in words, the count, the rows with their
/// restore, and the sentinel that walks the pages.
private struct TrashList: View {
    let model: TrashModel

    @State private var alertMessage: String?

    var body: some View {
        Group {
            if model.items.isEmpty {
                if model.loading {
                    LoadingView()
                } else if let error = model.error {
                    ErrorView(error: error, retry: { await model.load() })
                } else {
                    EmptyStateView(
                        systemImage: "trash",
                        title: "Lixeira vazia",
                        message: "Nada esperando para ser apagado."
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
        .alert(
            "Não deu certo",
            isPresented: Binding(
                get: { alertMessage != nil },
                set: { if !$0 { alertMessage = nil } }
            ),
            presenting: alertMessage
        ) { _ in
            Button("Entendi", role: .cancel) {}
        } message: { message in
            Text(message)
        }
    }

    private var list: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: Theme.Space.space4) {
                RowCard {
                    HStack(alignment: .top, spacing: Theme.Space.space3) {
                        Image(systemName: "clock")
                            .typeStyle(Theme.Text.h3)
                            .foregroundStyle(Theme.Palette.feedbackWarning)
                        Text("Itens são apagados para sempre após \(TrashModel.retentionDays) dias na lixeira.")
                            .typeStyle(Theme.Text.bodySm)
                            .foregroundStyle(Theme.Palette.textSecondary)
                    }
                }
                Text(TrashModel.countLabel(count: model.items.count, hasMore: model.nextCursor != nil))
                    .typeStyle(Theme.Text.overline)
                    .foregroundStyle(Theme.Palette.textMuted)
                ForEach(model.items, id: \.rkey) { file in
                    TrashRow(
                        file: file,
                        restoring: model.restoringRkey == file.rkey,
                        onRestore: {
                            Task {
                                if case .failure(let error) = await model.restore(rkey: file.rkey) {
                                    alertMessage = error.errorDescription ?? "Não foi possível restaurar o arquivo."
                                }
                            }
                        }
                    )
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
                    Text("Não foi possível carregar mais itens.")
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

/// One discarded file: the mime glyph, the name, the size and the trash
/// meta (in warning color when the purge is close), and the restore.
private struct TrashRow: View {
    let file: File
    var restoring: Bool
    let onRestore: () -> Void

    var body: some View {
        RowCard {
            HStack(spacing: Theme.Space.space3) {
                Image(systemName: TrashModel.glyph(for: file.mime))
                    .typeStyle(Theme.Text.h3)
                    .foregroundStyle(Theme.Palette.textFaint)
                    .frame(width: Theme.Size.controlMd, height: Theme.Size.controlMd)
                    .background(Theme.Palette.surfaceRaised, in: RoundedRectangle(cornerRadius: Theme.Radius.sm))
                VStack(alignment: .leading, spacing: Theme.Space.space1) {
                    Text(file.name)
                        .typeStyle(Theme.Text.label)
                        .foregroundStyle(Theme.Palette.textPrimary)
                        .lineLimit(1)
                        .multilineTextAlignment(.leading)
                    Text("\(Format.bytes(file.size)) / \(TrashModel.meta(for: file))")
                        .typeStyle(Theme.Text.monoSm)
                        .foregroundStyle(TrashModel.isWarning(file) ? Theme.Palette.feedbackWarning : Theme.Palette.textMuted)
                }
                Spacer()
                RestoreButton(loading: restoring, action: onRestore)
            }
        }
    }
}

/// The row's action: the restore glyph at the touch size, its own spinner
/// while the call runs.
private struct RestoreButton: View {
    var loading = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Group {
                if loading {
                    ProgressView()
                } else {
                    Label("Restaurar", systemImage: "arrow.uturn.backward")
                        .labelStyle(.iconOnly)
                }
            }
            .typeStyle(Theme.Text.h3)
            .foregroundStyle(Theme.Palette.serviceYbira)
            .frame(width: Theme.Size.touch, height: Theme.Size.touch)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(loading)
    }
}

#if DEBUG
#Preview("Lixeira") {
    PreviewHost(make: {
        let session = await SessionModel.previewSignedIn()
        // Three of the fake's files, discarded, so the rows have names,
        // sizes and zones to read.
        for rkey in ["3m2a8twqpv5z2", "3m7d1wyzr4c8u", "3m9f4xk1q7v2n"] {
            _ = await session.api.deleteFile(rkey: rkey)
        }
        return session
    }) { session in
        TrashView()
            .environment(session)
    }
}

#Preview("Lixeira vazia") {
    PreviewHost(make: { await SessionModel.previewSignedIn() }) { session in
        TrashView()
            .environment(session)
    }
}
#endif
