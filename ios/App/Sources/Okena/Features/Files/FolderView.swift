import OkenaCore
import SwiftUI

/// The same browser one level down: its own model over the folder's rkey,
/// so the loading logic and the pure transitions are FilesModel's, not a
/// copy. The menu holds the folder's own acts: publish or take back,
/// rename, move, delete, each with the confirmation the web asks for.
struct FolderView: View {
    @State private var folder: Folder

    @Environment(SessionModel.self) private var session
    @Environment(\.dismiss) private var dismiss
    @State private var model: FilesModel?
    @State private var working = false
    @State private var failure: TainaError?
    @State private var showingRename = false
    @State private var newName = ""
    @State private var showingMove = false
    @State private var confirmingZona = false
    @State private var confirmingDelete = false

    init(folder: Folder) {
        _folder = State(initialValue: folder)
    }

    var body: some View {
        Group {
            if let model {
                BrowserList(model: model)
            } else {
                LoadingView()
            }
        }
        .navigationTitle(folder.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { menu }
        .task(id: folder.rkey) {
            if model == nil {
                model = session.makeFilesModel(folderRkey: folder.rkey)
            }
        }
        .alert("Renomear", isPresented: $showingRename) {
            TextField("Novo nome", text: $newName)
            Button("Renomear") {
                Task { await rename() }
            }
            Button("Cancelar", role: .cancel) {}
        }
        .sheet(isPresented: $showingMove) {
            MoveSheet(sourceRkey: folder.rkey, name: folder.name) { parent in
                await move(to: parent)
            }
        }
        .confirmationDialog(
            FilesModel.zonaConfirmTitle(name: folder.name, zona: folder.zona),
            isPresented: $confirmingZona,
            titleVisibility: .visible
        ) {
            Button(FilesModel.zonaConfirmPrimary(for: folder.zona)) {
                Task { await changeZona() }
            }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text(FilesModel.zonaFolderBody(name: folder.name, zona: folder.zona))
        }
        .confirmationDialog(
            FilesModel.deleteFolderTitle(name: folder.name),
            isPresented: $confirmingDelete,
            titleVisibility: .visible
        ) {
            Button("Excluir", role: .destructive) {
                Task { await delete() }
            }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text(FilesModel.deleteFolderMessage)
        }
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

    @ToolbarContentBuilder
    private var menu: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                Button {
                    confirmingZona = true
                } label: {
                    Label(
                        FilesModel.zonaActionLabel(for: folder.zona),
                        systemImage: folder.zona == .casa ? "person.2" : "lock"
                    )
                }
                Button {
                    newName = folder.name
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

    private func rename() async {
        guard let model else { return }
        let name = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, name != folder.name else { return }
        working = true
        failure = nil
        switch await model.renameFolder(folder, to: name) {
        case .success(let updated):
            folder = updated
        case .failure(let error):
            failure = error
        }
        working = false
    }

    private func move(to parent: Folder?) async -> TainaResult<Void> {
        guard let model else {
            return .failure(.cancelled)
        }
        switch await model.moveFolder(folder, to: parent) {
        case .success(let updated):
            folder = updated
            return .success(())
        case .failure(let error):
            return .failure(error)
        }
    }

    private func changeZona() async {
        guard let model else { return }
        // The action always offers the opposite of where the folder is now.
        let target: Zona = folder.zona == .casa ? .praca : .casa
        working = true
        failure = nil
        switch await model.setFolderZone(folder, to: target) {
        case .success(let updated):
            folder = updated
        case .failure(let error):
            failure = error
        }
        working = false
    }

    private func delete() async {
        guard let model else { return }
        working = true
        failure = nil
        switch await model.deleteFolder(folder) {
        case .success:
            working = false
            // The folder is in the trash; the listing above is where the
            // person goes.
            dismiss()
            return
        case .failure(let error):
            failure = error
        }
        working = false
    }
}

#if DEBUG
#Preview("Pasta vazia") {
    PreviewHost(make: { await SessionModel.previewEmptyFolder() }) { seed in
        if let folder = seed.folder {
            FolderView(folder: folder)
                .environment(seed.model)
        } else {
            FilesView()
                .environment(seed.model)
        }
    }
}
#endif
