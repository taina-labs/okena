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
                BrowserList(model: model)
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
/// pure transitions, no copy between screens.
struct BrowserList: View {
    let model: FilesModel

    @State private var showingNewFolder = false
    @State private var newFolderName = ""
    @State private var showingImporter = false
    @State private var alertMessage: String?

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
        .background(Theme.Palette.bgApp)
        .toolbar { toolbar }
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
            message: "Guarde um arquivo com o botão de enviar, no topo da tela, ou crie uma pasta para organizar.",
            action: EmptyStateAction(title: "Nova pasta") {
                showingNewFolder = true
            }
        )
    }

    private var list: some View {
        ScrollView {
            LazyVStack(spacing: Theme.Space.space2) {
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
                ForEach(model.entries.files, id: \.rkey) { file in
                    NavigationLink {
                        FileDetailView(file: file)
                    } label: {
                        FileRow(file: file)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(Theme.Space.space4)
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
}

#if DEBUG
#Preview("Arquivos, raiz") {
    PreviewHost(make: { await SessionModel.previewSignedIn() }) { session in
        FilesView()
            .environment(session)
    }
}
#endif
