import OkenaCore
import QuickLook
import SwiftUI

/// The file: the thumbnail large, the facts in mono, and the actions.
/// "Baixar" becomes "Compartilhar" once the file is here; the preview
/// opens on the same downloaded file. The owner's acts sit in the menu:
/// publish or take back, rename, move, delete, each with the confirmation
/// the web asks for. A casa the person cannot read turns the screen into
/// the access request: the box says the file is not for our eyes, the
/// person asks, the owner decides.
struct FileDetailView: View {
    @State private var file: File

    @Environment(SessionModel.self) private var session
    @Environment(\.dismiss) private var dismiss
    @State private var downloadedURL: URL?
    @State private var previewURL: URL?
    @State private var working = false
    @State private var failure: TainaError?
    @State private var resolving = false
    @State private var denied: AccessTarget?
    @State private var askingAccess = false
    @State private var requested = false
    @State private var showingRename = false
    @State private var newName = ""
    @State private var showingMove = false
    @State private var confirmingZona = false
    @State private var confirmingDelete = false

    init(file: File) {
        _file = State(initialValue: file)
    }

    var body: some View {
        Group {
            if resolving {
                LoadingView()
            } else if let denied {
                deniedContent(denied)
            } else {
                fileContent
            }
        }
        .background(Theme.Palette.bgApp)
        .navigationTitle(denied == nil ? "Arquivo" : "Pedir acesso")
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
        .alert("Renomear", isPresented: $showingRename) {
            TextField("Novo nome", text: $newName)
            Button("Renomear") {
                Task { await rename() }
            }
            Button("Cancelar", role: .cancel) {}
        }
        .sheet(isPresented: $showingMove) {
            MoveSheet(sourceRkey: file.rkey, name: file.name, isFolder: false) { folder in
                await move(to: folder)
            }
        }
        .confirmationDialog(
            FilesModel.zonaConfirmTitle(name: file.name, zona: file.zona),
            isPresented: $confirmingZona,
            titleVisibility: .visible
        ) {
            Button(FilesModel.zonaConfirmPrimary(for: file.zona)) {
                Task { await changeZona() }
            }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text(FilesModel.zonaConfirmBody(for: file.zona))
        }
        .confirmationDialog(
            FilesModel.deleteFileTitle(name: file.name),
            isPresented: $confirmingDelete,
            titleVisibility: .visible
        ) {
            Button("Excluir", role: .destructive) {
                Task { await delete() }
            }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text(FilesModel.deleteFileMessage)
        }
        .confirmationDialog(
            denied.map { "Pedir acesso a \"\($0.name)\"?" } ?? "Pedir acesso",
            isPresented: $askingAccess,
            titleVisibility: .visible,
            presenting: denied
        ) { target in
            Button("Pedir acesso") {
                Task { await requestAccess(target) }
            }
            Button("Cancelar", role: .cancel) {}
        } message: { _ in
            Text("Quem guarda este arquivo vai receber seu pedido e decide se abre. Você só verá o conteúdo se a pessoa deixar.")
        }
        .alert("Pedido enviado", isPresented: $requested) {
            Button("Entendi", role: .cancel) { dismiss() }
        } message: {
            Text("A pessoa que guarda o arquivo recebe seu pedido e decide se abre.")
        }
    }

    private var fileContent: some View {
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
        .toolbar { menu }
    }

    /// Casa de outra pessoa: a pessoa nao le o conteudo, mas a tela diz a
    /// quem pedir. The owner's menu is gone: there is nothing to own here.
    private func deniedContent(_ target: AccessTarget) -> some View {
        VStack {
            EmptyStateView(
                systemImage: "shield",
                title: "Esta casa é particular",
                message: "Só quem mora aqui vê este arquivo. Para abrir, peça acesso e a pessoa decide. O Tainá ainda não criptografa: é promessa de software, não cadeado.",
                action: EmptyStateAction(title: "Pedir acesso") {
                    askingAccess = true
                }
            )
            Spacer()
        }
    }

    private var meta: some View {
        RowCard {
            VStack(alignment: .leading, spacing: Theme.Space.space3) {
                row("Tamanho", Format.bytes(file.size))
                row("Tipo", FilesModel.fileKind(file.mime), note: file.mime)
                row("Criado em", Format.date(file.createdAt))
                row("Atualizado em", Format.date(file.updatedAt))
                row(FilesModel.hashLabel, file.sha256, note: FilesModel.hashNote)
            }
        }
    }

    private func row(_ label: String, _ value: String, note: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.space1) {
            Text(label)
                .typeStyle(Theme.Text.overline)
                .foregroundStyle(Theme.Palette.textMuted)
            Text(value)
                .typeStyle(Theme.Text.monoSm)
                .foregroundStyle(Theme.Palette.textPrimary)
                .textSelection(.enabled)
            if let note {
                Text(note)
                    .typeStyle(Theme.Text.caption)
                    .foregroundStyle(Theme.Palette.textMuted)
            }
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

    @ToolbarContentBuilder
    private var menu: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                Button {
                    confirmingZona = true
                } label: {
                    Label(
                        FilesModel.zonaActionLabel(for: file.zona),
                        systemImage: file.zona == .casa ? "person.2" : "lock"
                    )
                }
                Button {
                    newName = file.name
                    showingRename = true
                } label: {
                    Label("Renomear", systemImage: "pencil")
                }
                Button {
                    showingMove = true
                } label: {
                    Label("Mover", systemImage: "folder")
                }
                Button(role: .destructive) {
                    confirmingDelete = true
                } label: {
                    Label("Excluir", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
            .accessibilityLabel("Mais opções")
            .disabled(working)
        }
    }

    // MARK: internals

    private func download() async {
        working = true
        failure = nil
        let result = await session.api.download(rkey: file.rkey)
        switch await session.screen(result) {
        case .success(let url):
            downloadedURL = url
        case .failure(let error):
            await onDownloadFailure(error)
        }
        working = false
    }

    /// A 403 on the content is the casa of another person: the screen
    /// becomes the access request, with the owner the box names.
    private func onDownloadFailure(_ error: TainaError) async {
        guard case .api(let failure) = error, failure.isForbidden else {
            self.failure = error
            return
        }
        resolving = true
        let target = await session.api.accessTarget(fileRkey: file.rkey)
        switch await session.screen(target) {
        case .success(let found):
            denied = found
        case .failure(let missed):
            self.failure = missed
        }
        resolving = false
    }

    private func preview() async {
        if let downloadedURL {
            previewURL = downloadedURL
            return
        }
        await download()
        previewURL = downloadedURL
    }

    private func rename() async {
        let name = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, name != file.name else { return }
        working = true
        failure = nil
        let result = await session.api.updateFile(rkey: file.rkey, name: name, zona: nil)
        switch await session.screen(result) {
        case .success(let updated):
            file = updated
        case .failure(let error):
            failure = error
        }
        working = false
    }

    private func move(to folder: Folder?) async -> TainaResult<Void> {
        let result = await session.api.moveFile(rkey: file.rkey, folderRkey: folder?.rkey)
        switch await session.screen(result) {
        case .success(let updated):
            file = updated
            return .success(())
        case .failure(let error):
            return .failure(error)
        }
    }

    private func changeZona() async {
        // The action always offers the opposite of where the file is now.
        let target: Zona = file.zona == .casa ? .praca : .casa
        working = true
        failure = nil
        let result = await session.api.updateFile(rkey: file.rkey, name: nil, zona: target)
        switch await session.screen(result) {
        case .success(let updated):
            file = updated
        case .failure(let error):
            failure = error
        }
        working = false
    }

    private func delete() async {
        working = true
        failure = nil
        let result = await session.api.deleteFile(rkey: file.rkey)
        switch await session.screen(result) {
        case .success:
            working = false
            // The file is in the trash; the browser is where the person goes.
            dismiss()
            return
        case .failure(let error):
            failure = error
        }
        working = false
    }

    private func requestAccess(_ target: AccessTarget) async {
        working = true
        failure = nil
        let result = await session.api.requestAccess(fileRkey: target.rkey, motivo: FilesModel.accessMotivo)
        switch await session.screen(result) {
        case .success:
            requested = true
        case .failure(let error):
            failure = error
        }
        working = false
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
