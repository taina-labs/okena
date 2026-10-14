import OkenaCore
import QuickLook
import SwiftUI

/// The file: the thumbnail large, the facts in mono, and the two actions.
/// "Baixar" becomes "Compartilhar" once the file is here; the preview
/// opens on the same downloaded file.
struct FileDetailView: View {
    let file: File

    @Environment(SessionModel.self) private var session
    @State private var downloadedURL: URL?
    @State private var previewURL: URL?
    @State private var working = false
    @State private var failure: TainaError?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Space.space5) {
                FileThumbnail(rkey: file.rkey, size: .md, side: Theme.Size.qr)
                    .frame(maxWidth: .infinity, alignment: .center)
                Text(file.name)
                    .typeStyle(Theme.Text.h2)
                    .foregroundStyle(Theme.Palette.textPrimary)
                ZonaBadge(zona: file.zona)
                meta
                actions
            }
            .padding(Theme.Space.space5)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Theme.Palette.bgApp)
        .navigationTitle("Arquivo")
        .navigationBarTitleDisplayMode(.inline)
        .quickLookPreview($previewURL)
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

    private var meta: some View {
        RowCard {
            VStack(alignment: .leading, spacing: Theme.Space.space3) {
                row("Tamanho", Format.bytes(file.size))
                row("Tipo", file.mime)
                row("Criado em", Format.date(file.createdAt))
                row("Atualizado em", Format.date(file.updatedAt))
                row("sha256", file.sha256)
            }
        }
    }

    private func row(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.space1) {
            Text(label)
                .typeStyle(Theme.Text.overline)
                .foregroundStyle(Theme.Palette.textMuted)
            Text(value)
                .typeStyle(Theme.Text.monoSm)
                .foregroundStyle(Theme.Palette.textPrimary)
                .textSelection(.enabled)
        }
    }

    private var actions: some View {
        HStack(spacing: Theme.Space.space3) {
            if working {
                ProgressView()
                    .frame(maxWidth: .infinity, minHeight: Theme.Size.controlMd)
            } else if let downloadedURL {
                ShareLink(item: downloadedURL) {
                    Text("Compartilhar")
                }
                .buttonStyle(PrimaryButtonStyle())
            } else {
                PrimaryButton(title: "Baixar") {
                    Task { await download() }
                }
            }
            SecondaryButton(title: "Pré-visualizar") {
                Task { await preview() }
            }
        }
    }

    private func download() async {
        working = true
        failure = nil
        let result = await session.api.download(rkey: file.rkey)
        switch await session.screen(result) {
        case .success(let url):
            downloadedURL = url
        case .failure(let error):
            failure = error
        }
        working = false
    }

    private func preview() async {
        if let downloadedURL {
            previewURL = downloadedURL
            return
        }
        await download()
        previewURL = downloadedURL
    }
}

#if DEBUG
#Preview("Arquivo") {
    PreviewHost(make: { await SessionModel.previewFile() }) { seed in
        if let file = seed.file {
            FileDetailView(file: file)
                .environment(seed.model)
        } else {
            FilesView()
                .environment(seed.model)
        }
    }
}
#endif
