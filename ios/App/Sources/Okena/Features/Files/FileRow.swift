import OkenaCore
import SwiftUI

/// A file row: the thumbnail (a document glyph when there is none), the
/// name, and a secondary line of size and date, scanned in mono. The praça
/// badge shows only for the praça, where being public is the news.
struct FileRow: View {
    let file: File

    var body: some View {
        RowCard {
            HStack(spacing: Theme.Space.space3) {
                FileThumbnail(rkey: file.rkey, size: .sm)
                VStack(alignment: .leading, spacing: Theme.Space.space1) {
                    Text(file.name)
                        .typeStyle(Theme.Text.label)
                        .foregroundStyle(Theme.Palette.textPrimary)
                        .lineLimit(1)
                        .multilineTextAlignment(.leading)
                    Text("\(Format.bytes(file.size)) / \(Format.relative(file.createdAt))")
                        .typeStyle(Theme.Text.monoSm)
                        .foregroundStyle(Theme.Palette.textMuted)
                    if file.zona == .praca {
                        ZonaBadge(zona: file.zona)
                    }
                }
                Spacer()
            }
        }
    }
}

/// The thumbnail, from the shared store: a placeholder while it loads and
/// a document glyph when the file has none.
struct FileThumbnail: View {
    let rkey: String
    var size: ThumbnailSize = .sm
    var side: CGFloat = Theme.Size.controlMd

    @Environment(SessionModel.self) private var session
    @State private var image: UIImage?
    @State private var missing = false

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else if missing {
                Image(systemName: "document")
                    .typeStyle(Theme.Text.h3)
                    .foregroundStyle(Theme.Palette.textFaint)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Theme.Palette.surfaceRaised)
            } else {
                Rectangle()
                    .fill(Theme.Palette.surfaceRaised)
                    .overlay {
                        ProgressView()
                            .tint(Theme.Palette.textMuted)
                    }
            }
        }
        .frame(width: side, height: side)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.sm))
        .task(id: rkey) {
            await load()
        }
    }

    private func load() async {
        let result = await session.thumbnails.data(rkey: rkey, size: size)
        switch result {
        case .success(let data):
            if let decoded = UIImage(data: data) {
                image = decoded
            } else {
                missing = true
            }
        case .failure:
            missing = true
        }
    }
}
