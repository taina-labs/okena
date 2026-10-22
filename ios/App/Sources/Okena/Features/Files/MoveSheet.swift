import OkenaCore
import SwiftUI

/// The move modal, one for files and folders alike: the root and every
/// folder, one tap to move. The sheet offers only the destinations the
/// client can vouch for: never the source itself, and for a folder
/// source none of its descendants, where the move would close a cycle.
/// What the record cannot say is ownership: the web filters to the
/// person's own folders, but the record the app reads carries no owner,
/// so those still show and the box has the last word.
struct MoveSheet: View {
    let sourceRkey: String
    let name: String
    var isFolder = false
    let onPick: (Folder?) async -> TainaResult<Void>

    @Environment(SessionModel.self) private var session
    @Environment(\.dismiss) private var dismiss
    @State private var folders: [Folder] = []
    @State private var loading = true
    @State private var loadFailure: TainaError?
    @State private var moving = false
    @State private var pickFailure: TainaError?

    var body: some View {
        NavigationStack {
            Group {
                if loading {
                    LoadingView()
                } else if let loadFailure {
                    ErrorView(error: loadFailure, retry: { await load() })
                } else {
                    list
                }
            }
            .background(Theme.Palette.bgApp)
            .navigationTitle("Mover para...")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .task { await load() }
        .alert(
            "Não deu certo",
            isPresented: Binding(
                get: { pickFailure != nil },
                set: { if !$0 { pickFailure = nil } }
            ),
            presenting: pickFailure
        ) { _ in
            Button("Entendi", role: .cancel) {}
        } message: { error in
            Text(error.errorDescription ?? "Algo deu errado. Tente de novo.")
        }
    }

    private var list: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Space.space4) {
                Text(name)
                    .typeStyle(Theme.Text.bodySm)
                    .foregroundStyle(Theme.Palette.textMuted)
                LazyVStack(spacing: Theme.Space.space2) {
                    destination(nil, icon: "house", label: "Início (raiz)")
                    ForEach(destinations, id: \.rkey) { folder in
                        destination(folder, icon: "folder", label: folder.name)
                    }
                }
            }
            .padding(Theme.Space.space4)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    /// The folders the sheet offers, the model's filter over what the
    /// box answered.
    private var destinations: [Folder] {
        FilesModel.moveDestinations(from: sourceRkey, isFolder: isFolder, among: folders)
    }

    private func destination(_ folder: Folder?, icon: String, label: String) -> some View {
        Button {
            Task { await pick(folder) }
        } label: {
            RowCard {
                HStack(spacing: Theme.Space.space3) {
                    Image(systemName: icon)
                        .typeStyle(Theme.Text.h3)
                        .foregroundStyle(Theme.Palette.serviceYbira)
                    Text(label)
                        .typeStyle(Theme.Text.label)
                        .foregroundStyle(Theme.Palette.textPrimary)
                        .lineLimit(1)
                        .multilineTextAlignment(.leading)
                    Spacer()
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(moving)
    }

    // MARK: internals

    private func load() async {
        loading = true
        loadFailure = nil
        let result = await session.api.listFolders()
        switch await session.screen(result) {
        case .success(let found):
            folders = found
        case .failure(let error):
            loadFailure = error
        }
        loading = false
    }

    private func pick(_ folder: Folder?) async {
        moving = true
        pickFailure = nil
        let result = await onPick(folder)
        moving = false
        switch result {
        case .success:
            dismiss()
        case .failure(let error):
            pickFailure = error
        }
    }
}

#if DEBUG
#Preview("Mover") {
    PreviewHost(make: { await SessionModel.previewFile() }) { seed in
        if let file = seed.file {
            MoveSheet(sourceRkey: file.rkey, name: file.name, isFolder: false) { _ in .success(()) }
                .environment(seed.model)
        } else {
            FilesView()
                .environment(seed.model)
        }
    }
}
#endif
