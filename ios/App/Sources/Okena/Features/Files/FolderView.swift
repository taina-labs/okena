import OkenaCore
import SwiftUI

/// The same browser one level down: its own model over the folder's rkey,
/// so the loading logic and the pure transitions are FilesModel's, not a
/// copy.
struct FolderView: View {
    let folder: Folder

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
        .navigationTitle(folder.name)
        .navigationBarTitleDisplayMode(.inline)
        .task(id: folder.rkey) {
            if model == nil {
                model = session.makeFilesModel(folderRkey: folder.rkey)
            }
        }
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
