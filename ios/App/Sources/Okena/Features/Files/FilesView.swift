import OkenaCore
import SwiftUI
import UniformTypeIdentifiers

/// The browser's root: the community's own folder.
struct FilesView: View {
    @Environment(SessionModel.self) private var session
    @State private var model: FilesModel?

    var body: some View {
        Group {
            if let model {
                BrowserList(model: model, destinationZona: .casa)
            } else {
                LoadingView()
            }
        }
        .navigationTitle("Arquivos")
        .task {
            if model == nil {
                model = session.makeFilesModel(folderRkey: nil)
            }
        }
    }
}

/// The list the root and any folder show: one loading logic, the model's
/// pure transitions, no copy between screens. The screen names where an
/// upload lands and the freshly uploaded rows still carry the one-tap
/// publish to the praca.
struct BrowserList: View {
    let model: FilesModel
    let destinationZona: Zona

    @State private var showingNewFolder = false
    @State private var newFolderName = ""
    @State private var showingImporter = false
    @State private var alertMessage: String?
    @State private var showingTrash = BrowserList.initialShowingTrash()

    var body: some View {
        Group {
            if FilesModel.isEmpty(model.entries) {
                if model.loading {
                    LoadingView()
                } else if let error = model.error {
                    ErrorView(error: error, retry: { await model.load() })
                } else {
                    emptyState
                }
            } else {
                list
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Theme.Palette.bgApp)
        .toolbar { toolbar }
        .navigationDestination(isPresented: $showingTrash) {
            TrashView()
        }
        // Loads on appear and on pull: the list owns its own loading, for
        // the root and for any folder.
        .task { await model.load() }
        .refreshable { await model.load() }
        .fileImporter(
            isPresented: $showingImporter,
            allowedContentTypes: [.data],
            allowsMultipleSelection: false,
            onCompletion: picked
        )
        .alert("Nova pasta", isPresented: $showingNewFolder) {
            TextField("Nome da pasta", text: $newFolderName)
            Button("Criar") {
                Task { await createFolder() }
            }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("As pastas nascem na sua casa. Publicar na praça da comunidade vem depois.")
        }
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

    private var emptyState: some View {
        EmptyStateView(
            systemImage: "folder",
            title: "Esta pasta está vazia",
            message: "Guarde um arquivo com o botão de enviar, no topo da tela, ou crie uma pasta para organizar. "
                + FilesModel.uploadDestinationMessage(for: destinationZona),
            action: EmptyStateAction(title: "Nova pasta") {
                showingNewFolder = true
            }
        )
    }

    private var list: some View {
        ScrollView {
            LazyVStack(spacing: Theme.Space.space2) {
                Text(FilesModel.uploadDestinationMessage(for: destinationZona))
                    .typeStyle(Theme.Text.bodySm)
                    .foregroundStyle(Theme.Palette.textMuted)
                    .frame(maxWidth: .infinity, alignment: .leading)
                ForEach(model.entries.folders, id: \.rkey) { folder in
                    NavigationLink {
                        FolderView(folder: folder)
                    } label: {
                        RowCard {
                            HStack(spacing: Theme.Space.space3) {
                                Image(systemName: "folder")
                                    .typeStyle(Theme.Text.h3)
                                    .foregroundStyle(Theme.Palette.serviceYbira)
                                VStack(alignment: .leading, spacing: Theme.Space.space1) {
                                    Text(folder.name)
                                        .typeStyle(Theme.Text.label)
                                        .foregroundStyle(Theme.Palette.textPrimary)
                                        .lineLimit(1)
                                        .multilineTextAlignment(.leading)
                                    if folder.zona == .praca {
                                        ZonaBadge(zona: folder.zona)
                                    }
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .typeStyle(Theme.Text.caption)
                                    .foregroundStyle(Theme.Palette.textFaint)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
                if !model.entries.files.isEmpty {
                    Text(FilesModel.countLabel(count: model.entries.files.count, hasMore: model.nextCursor != nil))
                        .typeStyle(Theme.Text.overline)
                        .foregroundStyle(Theme.Palette.textMuted)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                ForEach(model.entries.files, id: \.rkey) { file in
                    NavigationLink {
                        FileDetailView(file: file)
                    } label: {
                        FileRow(file: file)
                    }
                    .buttonStyle(.plain)
                    if model.showsPublishAction(file) {
                        publishAction(for: file)
                    }
                }
                sentinel
            }
            .padding(Theme.Space.space4)
        }
    }

    /// The completed upload's action, its own card under the row so the
    /// tap never shares a surface with the navigation. While the file
    /// stays in the casa, the action is the way to the praca.
    private func publishAction(for file: File) -> some View {
        Button {
            Task { await publish(file) }
        } label: {
            RowCard {
                HStack(spacing: Theme.Space.space3) {
                    if model.publishingRkey == file.rkey {
                        ProgressView()
                            .tint(Theme.Palette.serviceYbira)
                    } else {
                        Image(systemName: "person.2")
                            .typeStyle(Theme.Text.h3)
                            .foregroundStyle(Theme.Palette.serviceYbira)
                    }
                    Text(FilesModel.zonaActionLabel(for: .casa))
                        .typeStyle(Theme.Text.label)
                        .foregroundStyle(Theme.Palette.serviceYbira)
                    Spacer()
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(model.publishingRkey != nil)
    }

    /// The next page of files: a spinner that loads on sight, or the
    /// retry when a page failed. It only exists while the server still
    /// has rows.
    @ViewBuilder
    private var sentinel: some View {
        if model.nextCursor != nil {
            if model.moreError {
                VStack(spacing: Theme.Space.space2) {
                    Text("Não foi possível carregar mais arquivos.")
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

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button {
                showingNewFolder = true
            } label: {
                Label("Nova pasta", systemImage: "folder.badge.plus")
            }
        }
        ToolbarItem(placement: .topBarLeading) {
            Button {
                showingTrash = true
            } label: {
                Label("Lixeira", systemImage: "trash")
            }
        }
        ToolbarItem(placement: .topBarTrailing) {
            if model.uploading {
                ProgressView()
            } else {
                Button {
                    showingImporter = true
                } label: {
                    Label("Enviar arquivo", systemImage: "square.and.arrow.up")
                }
            }
        }
    }

    /// In DEBUG, `TAINA_FILES=lixeira` opens the Lixeira on launch, the same
    /// seam the shell uses, so a script or a UI test reaches it without
    /// tapping. The running app reaches it through the toolbar.
    private static func initialShowingTrash() -> Bool {
        #if DEBUG
        return ProcessInfo.processInfo.environment["TAINA_FILES"] == "lixeira"
        #else
        return false
        #endif
    }

    private func picked(_ outcome: Result<[URL], any Error>) {
        switch outcome {
        case .success(let urls):
            guard let url = urls.first else { return }
            Task {
                let result = await model.upload(from: url)
                if case .failure(let error) = result {
                    alertMessage = FilesModel.uploadMessage(for: error)
                }
            }
        case .failure:
            alertMessage = "Não deu para abrir o seletor de arquivos."
        }
    }

    private func createFolder() async {
        let name = newFolderName.trimmingCharacters(in: .whitespacesAndNewlines)
        newFolderName = ""
        guard !name.isEmpty else { return }
        let result = await model.createFolder(named: name)
        if case .failure(let error) = result {
            alertMessage = error.errorDescription
        }
    }

    private func publish(_ file: File) async {
        let result = await model.publish(file)
        if case .failure(let error) = result {
            alertMessage = error.errorDescription ?? "Não foi possível publicar na praça."
        }
    }
}

#if DEBUG
#Preview("Arquivos, raiz") {
    PreviewHost(make: { await SessionModel.previewSignedIn() }) { session in
        FilesView()
            .environment(session)
    }
}
#endif
