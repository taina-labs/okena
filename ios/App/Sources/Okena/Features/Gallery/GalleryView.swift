import OkenaCore
import SwiftUI

/// Jaci, the Fotos screen: grid and timeline on one segmented row, infinite
/// scroll on both, and the fullscreen viewer over whichever list is showing
/// (the web's gallery_live).
struct GalleryView: View {
    @Environment(SessionModel.self) private var session
    @State private var model: GalleryModel?

    var body: some View {
        Group {
            if let model {
                GalleryContent(model: model)
            } else {
                LoadingView()
            }
        }
        .navigationTitle("Fotos")
        .task {
            if model == nil {
                model = GalleryModel(api: session.api, session: session)
            }
        }
    }
}

/// The screen's content: the segmented row, the tab's list, the viewer
/// cover and the load-more alert.
struct GalleryContent: View {
    let model: GalleryModel

    var body: some View {
        GeometryReader { geo in
            VStack(spacing: Theme.Space.space4) {
                GallerySegment(model: model)
                content(width: geo.size.width)
            }
        }
        .background(Theme.Palette.bgApp)
        .task(id: model.tab) { await model.ensureLoaded() }
        .fullScreenCover(isPresented: viewerBinding) {
            GalleryViewer(model: model)
        }
        .alert(
            "Não deu certo",
            isPresented: Binding(
                get: { model.alertMessage != nil },
                set: { if !$0 { model.dismissAlert() } }
            ),
            presenting: model.alertMessage
        ) { _ in
            Button("Entendi", role: .cancel) {}
        } message: { message in
            Text(message)
        }
    }

    private var viewerBinding: Binding<Bool> {
        Binding(
            get: { model.viewer != nil },
            set: { if !$0 { model.close() } }
        )
    }

    @ViewBuilder
    private func content(width: CGFloat) -> some View {
        if empty {
            if model.loading {
                LoadingView()
            } else if let error = model.error {
                ErrorView(error: error, retry: { await model.refresh() })
            } else if model.loaded {
                EmptyStateView(
                    systemImage: "photo",
                    title: "Nenhuma foto ainda",
                    message: "As imagens que a comunidade enviar aparecem aqui."
                )
            }
        } else {
            list(width: width)
        }
    }

    private var empty: Bool {
        switch model.tab {
        case .grid: model.photos.isEmpty
        case .timeline: model.groups.isEmpty
        }
    }

    private func list(width: CGFloat) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Space.space5) {
                switch model.tab {
                case .grid:
                    tiles(model.photos, columns: GalleryModel.columns(for: width))
                case .timeline:
                    ForEach(model.timelineDays) { day in
                        section(day, columns: GalleryModel.columns(for: width))
                    }
                }
                footer
            }
            .padding(.horizontal, Theme.Space.space4)
            .padding(.bottom, Theme.Space.space4)
        }
        .refreshable { await model.refresh() }
    }

    private func section(_ day: GalleryModel.Day, columns: Int) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.space2) {
            Text(GalleryModel.sectionTitle(for: day))
                .typeStyle(Theme.Text.h3)
                .foregroundStyle(Theme.Palette.textPrimary)
            tiles(day.photos, columns: columns)
        }
    }

    private func tiles(_ files: [File], columns: Int) -> some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: Theme.Size.gapPhoto), count: columns),
            spacing: Theme.Size.gapPhoto
        ) {
            ForEach(files, id: \.rkey) { file in
                Button {
                    model.open(file)
                } label: {
                    GalleryTile(file: file)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(file.name)
            }
        }
    }

    /// The infinite-scroll sentinel: it loads the next page when it shows,
    /// and the task re-arms when a page lands.
    @ViewBuilder
    private var footer: some View {
        if model.canLoadMore {
            HStack(spacing: Theme.Space.space2) {
                ProgressView()
                    .tint(Theme.Palette.textMuted)
                Text("Carregando mais...")
                    .typeStyle(Theme.Text.caption)
                    .foregroundStyle(Theme.Palette.textMuted)
            }
            .frame(maxWidth: .infinity)
            .padding(Theme.Space.space3)
            .task(id: model.loadedCount) { await model.loadMore() }
        }
    }
}

/// The web's segmented control: two pills, the current one in brand.
struct GallerySegment: View {
    var model: GalleryModel

    var body: some View {
        HStack(spacing: Theme.Space.space2) {
            ForEach(GalleryModel.Tab.allCases, id: \.self) { tab in
                pill(tab)
            }
            Spacer()
        }
        .padding(.horizontal, Theme.Space.space4)
    }

    private func pill(_ tab: GalleryModel.Tab) -> some View {
        let current = model.tab == tab
        return Button {
            model.select(tab)
        } label: {
            Text(label(of: tab))
                .typeStyle(Theme.Text.label)
                .foregroundStyle(current ? Theme.Palette.textOnBrand : Theme.Palette.textSecondary)
                .padding(.horizontal, Theme.Space.space4)
                .frame(minHeight: Theme.Size.touch)
        }
        .background(current ? Theme.Palette.brandPrimary : Color.clear, in: Capsule())
        .overlay(
            Capsule().strokeBorder(
                current ? Theme.Palette.brandPrimary : Theme.Palette.borderDefault,
                lineWidth: Theme.Size.hairline
            )
        )
    }

    private func label(of tab: GalleryModel.Tab) -> String {
        switch tab {
        case .grid: "Grade"
        case .timeline: "Linha do tempo"
        }
    }
}

/// A grid tile: the square thumbnail, a play tile for videos (Jaci does
/// not make video thumbnails yet), the surface color while there is
/// nothing.
struct GalleryTile: View {
    let file: File

    @Environment(SessionModel.self) private var session
    @State private var image: UIImage?
    @State private var missing = false

    var body: some View {
        Group {
            if GalleryModel.isVideo(file) {
                Rectangle()
                    .fill(Theme.Palette.surfaceHigh)
                    .overlay {
                        Image(systemName: "play.fill")
                            .typeStyle(Theme.Text.h2)
                            .foregroundStyle(Theme.Palette.textSecondary)
                    }
            } else if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else if missing {
                Rectangle()
                    .fill(Theme.Palette.surfaceRaised)
            } else {
                Rectangle()
                    .fill(Theme.Palette.surfaceRaised)
                    .overlay {
                        ProgressView()
                            .tint(Theme.Palette.textMuted)
                    }
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.sm))
        .task(id: file.rkey) {
            await load()
        }
    }

    private func load() async {
        let result = await session.thumbnails.data(rkey: file.rkey, size: .sm)
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

/// The viewer's picture: the md thumbnail from the shared store, centered,
/// a quiet square when there is none.
struct GalleryImage: View {
    let rkey: String

    @Environment(SessionModel.self) private var session
    @State private var image: UIImage?
    @State private var missing = false

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
            } else {
                Rectangle()
                    .fill(Theme.Palette.surfaceRaised)
                    .overlay {
                        if !missing {
                            ProgressView()
                                .tint(Theme.Palette.textMuted)
                        }
                    }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task(id: rkey) {
            await load()
        }
    }

    private func load() async {
        let result = await session.thumbnails.data(rkey: rkey, size: .md)
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

/// The fullscreen viewer: a dark frame, one photo at a time, swipe between
/// the photos of the list it was opened from, close on top.
struct GalleryViewer: View {
    var model: GalleryModel

    var body: some View {
        Group {
            if let viewer = model.viewer {
                contents(viewer)
            }
        }
        .preferredColorScheme(.dark)
    }

    private func contents(_ viewer: GalleryModel.Viewer) -> some View {
        ZStack {
            Theme.Palette.bgViewer.ignoresSafeArea()
            VStack(spacing: 0) {
                header(viewer)
                stage(viewer)
                caption(viewer)
            }
        }
    }

    private func header(_ viewer: GalleryModel.Viewer) -> some View {
        HStack {
            Button {
                model.close()
            } label: {
                Image(systemName: "xmark")
                    .typeStyle(Theme.Text.h3)
                    .foregroundStyle(Theme.Palette.textPrimary)
                    .frame(width: Theme.Size.touch, height: Theme.Size.touch)
            }
            .accessibilityLabel("Fechar")
            Spacer()
            VStack(spacing: 0) {
                if let file = viewer.file {
                    Text(GalleryModel.uploadedDay(file.createdAt))
                        .typeStyle(Theme.Text.label)
                        .foregroundStyle(Theme.Palette.textPrimary)
                    Text("\(GalleryModel.position(of: file, in: viewer.files)) de \(viewer.files.count)")
                        .typeStyle(Theme.Text.caption)
                        .foregroundStyle(Theme.Palette.textFaint)
                }
            }
            Spacer()
            Color.clear
                .frame(width: Theme.Size.touch, height: Theme.Size.touch)
        }
    }

    private func stage(_ viewer: GalleryModel.Viewer) -> some View {
        TabView(
            selection: Binding(
                get: { viewer.index },
                set: { model.moveViewer(to: $0) }
            )
        ) {
            ForEach(Array(viewer.files.enumerated()), id: \.element.rkey) { offset, file in
                page(file)
                    .tag(offset)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
    }

    private func page(_ file: File) -> some View {
        Group {
            if GalleryModel.isVideo(file) {
                Rectangle()
                    .fill(Theme.Palette.surfaceHigh)
                    .overlay {
                        Image(systemName: "play.fill")
                            .typeStyle(Theme.Text.h2)
                            .foregroundStyle(Theme.Palette.textSecondary)
                    }
                    .aspectRatio(1, contentMode: .fit)
                    .padding(Theme.Space.space8)
            } else {
                GalleryImage(rkey: file.rkey)
            }
        }
    }

    private func caption(_ viewer: GalleryModel.Viewer) -> some View {
        Group {
            if let file = viewer.file {
                Text(file.name)
                    .typeStyle(Theme.Text.bodySm)
                    .foregroundStyle(Theme.Palette.textPrimary)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Theme.Space.space3)
                    .padding(.horizontal, Theme.Space.space4)
                    .background(Theme.Palette.surfaceScrimStrong)
            }
        }
    }
}

#if DEBUG
#Preview("Fotos, grade") {
    PreviewHost(make: { await SessionModel.previewSignedIn() }) { session in
        GalleryView()
            .environment(session)
    }
}

#Preview("Fotos, linha do tempo") {
    PreviewHost(make: {
        let session = await SessionModel.previewSignedIn()
        let model = GalleryModel(api: session.api, session: session)
        model.select(.timeline)
        return (session: session, model: model)
    }) { pair in
        GalleryContent(model: pair.model)
            .environment(pair.session)
    }
}

#Preview("Fotos, visualizador") {
    PreviewHost(make: {
        let session = await SessionModel.previewSignedIn()
        let model = GalleryModel(api: session.api, session: session)
        if case .success(let page) = await session.api.photos(limit: nil, cursor: nil),
           let photo = page.items.first(where: { !GalleryModel.isVideo($0) }) {
            model.open(photo)
        }
        return (session: session, model: model)
    }) { pair in
        GalleryContent(model: pair.model)
            .environment(pair.session)
    }
}
#endif
