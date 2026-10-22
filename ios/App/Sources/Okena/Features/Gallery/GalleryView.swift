import AVKit
import OkenaCore
import SwiftUI

/// Jaci, the Fotos screen: grid and timeline on one segmented row, the
/// casa/praça filter under it, infinite scroll on both, and the fullscreen
/// viewer over whichever list is showing (the web's gallery_live).
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

/// The screen's content: the two segmented rows, the tab's list, the
/// viewer cover and the load-more alert.
struct GalleryContent: View {
    let model: GalleryModel

    var body: some View {
        GeometryReader { geo in
            VStack(spacing: Theme.Space.space2) {
                GallerySegment(model: model)
                GalleryZoneFilter(model: model)
                content(width: geo.size.width)
                    .padding(.top, Theme.Space.space2)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
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
                let copy = GalleryModel.emptyCopy(rawEmpty: rawEmpty, filter: model.filter)
                EmptyStateView(
                    systemImage: copy.systemImage,
                    title: copy.title,
                    message: copy.message
                )
            }
        } else {
            list(width: width)
        }
    }

    private var empty: Bool {
        switch model.tab {
        case .grid: model.filteredPhotos.isEmpty
        case .timeline: model.timelineDays.isEmpty
        }
    }

    /// Whether the readable set itself is empty, filter aside: its empty
    /// state is the one that speaks first.
    private var rawEmpty: Bool {
        switch model.tab {
        case .grid: model.photos.isEmpty
        case .timeline: model.days.isEmpty
        }
    }

    private func list(width: CGFloat) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Space.space5) {
                switch model.tab {
                case .grid:
                    tiles(model.filteredPhotos, columns: GalleryModel.columns(for: width))
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

/// One capsule pill of a segmented row: the current one in brand.
private struct GalleryPill: View {
    let title: String
    let current: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
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
}

/// The web's segmented control: two pills, the current one in brand.
struct GallerySegment: View {
    var model: GalleryModel

    var body: some View {
        HStack(spacing: Theme.Space.space2) {
            ForEach(GalleryModel.Tab.allCases, id: \.self) { tab in
                GalleryPill(title: Self.label(of: tab), current: model.tab == tab) {
                    model.select(tab)
                }
            }
            Spacer()
        }
        .padding(.horizontal, Theme.Space.space4)
    }

    private static func label(of tab: GalleryModel.Tab) -> String {
        switch tab {
        case .grid: "Grade"
        case .timeline: "Linha do tempo"
        }
    }
}

/// The casa/praça filter, the web's row in Arquivos: the readable set
/// already carries both zones, so the pills only narrow what the screen
/// shows, and everything shows by default.
struct GalleryZoneFilter: View {
    var model: GalleryModel

    var body: some View {
        HStack(spacing: Theme.Space.space2) {
            ForEach(GalleryModel.Filter.allCases, id: \.self) { filter in
                GalleryPill(
                    title: GalleryModel.label(of: filter),
                    current: model.filter == filter
                ) {
                    model.select(filter)
                }
            }
            Spacer()
        }
        .padding(.horizontal, Theme.Space.space4)
    }
}

/// A grid tile: the square thumbnail, a play tile for videos (Jaci does
/// not make video thumbnails yet), the surface color while there is
/// nothing, and the zone on every tile: casa is the default, so the badge
/// never hides it (the web's photo-grid__tag).
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
        .overlay(alignment: .bottomTrailing) {
            ZonaBadge(zona: file.zona)
                .padding(Theme.Space.space2)
        }
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

/// The viewer's video page: Jaci makes no video thumbnails yet, so the
/// page stays the play surface until the person taps it; then the file
/// downloads and plays with the system player. The state is the page's
/// own, so the action row does not spin with it.
struct GalleryVideo: View {
    var model: GalleryModel
    let file: File

    private enum Phase: Equatable {
        case idle
        case loading
        case failed
    }

    @State private var phase = Phase.idle
    @State private var player: AVPlayer?

    var body: some View {
        Group {
            if let player {
                VideoPlayer(player: player)
            } else {
                surface
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .padding(Theme.Space.space8)
        .onDisappear { player?.pause() }
    }

    @ViewBuilder
    private var surface: some View {
        switch phase {
        case .idle:
            Button {
                Task { await play() }
            } label: {
                idle
            }
            .accessibilityLabel("Assistir \(file.name)")
        case .loading:
            surfaceFrame {
                VStack(spacing: Theme.Space.space3) {
                    ProgressView()
                        .tint(Theme.Palette.textMuted)
                    Text("Baixando vídeo...")
                        .typeStyle(Theme.Text.caption)
                        .foregroundStyle(Theme.Palette.textMuted)
                }
            }
        case .failed:
            surfaceFrame {
                VStack(spacing: Theme.Space.space3) {
                    Text("Não foi possível abrir o vídeo.")
                        .typeStyle(Theme.Text.caption)
                        .foregroundStyle(Theme.Palette.textMuted)
                        .multilineTextAlignment(.center)
                    SecondaryButton(title: "Tentar de novo") {
                        Task { await play() }
                    }
                }
                .padding(.horizontal, Theme.Space.space4)
            }
        }
    }

    private var idle: some View {
        surfaceFrame {
            VStack(spacing: Theme.Space.space3) {
                Image(systemName: "play.fill")
                    .typeStyle(Theme.Text.h2)
                    .foregroundStyle(Theme.Palette.textSecondary)
                Text("Toque para assistir")
                    .typeStyle(Theme.Text.caption)
                    .foregroundStyle(Theme.Palette.textMuted)
            }
        }
    }

    private func surfaceFrame(@ViewBuilder _ content: () -> some View) -> some View {
        ZStack {
            Rectangle()
                .fill(Theme.Palette.surfaceHigh)
            content()
                .padding(Theme.Space.space4)
        }
        .contentShape(Rectangle())
    }

    private func play() async {
        phase = .loading
        switch await model.play(file) {
        case .success(let url):
            let player = AVPlayer(url: url)
            self.player = player
            player.play()
            phase = .idle
        case .failure:
            phase = .failed
        }
    }
}

/// The fullscreen viewer: a dark frame, one photo at a time, swipe between
/// the photos of the list it was opened from, close on top, and the acts
/// the web's viewer has: share, details, publish or take back, delete.
struct GalleryViewer: View {
    var model: GalleryModel

    /// The one sheet the viewer presents: the details, or the share over
    /// the downloaded file.
    private enum Sheet: Identifiable {
        case details(File)
        case share(URL)

        var id: String {
            switch self {
            case .details(let file): file.rkey
            case .share(let url): url.absoluteString
            }
        }
    }

    @State private var sheet: Sheet?
    @State private var sharing = false
    @State private var confirmingZone = false
    @State private var confirmingDelete = false

    var body: some View {
        Group {
            if let viewer = model.viewer {
                contents(viewer)
            }
        }
        .preferredColorScheme(.dark)
        .sheet(item: $sheet) { sheet in
            switch sheet {
            case .details(let file):
                GalleryDetails(file: file)
            case .share(let url):
                ShareSheet(items: [url])
            }
        }
        .confirmationDialog(
            zonaTitle,
            isPresented: $confirmingZone,
            titleVisibility: .visible,
            presenting: model.viewer?.file
        ) { file in
            Button(FilesModel.zonaConfirmPrimary(for: file.zona)) {
                Task { await model.changeZone(of: file) }
            }
            Button("Cancelar", role: .cancel) {}
        } message: { file in
            Text(FilesModel.zonaConfirmBody(for: file.zona))
        }
        .confirmationDialog(
            deleteTitle,
            isPresented: $confirmingDelete,
            titleVisibility: .visible,
            presenting: model.viewer?.file
        ) { file in
            Button("Excluir", role: .destructive) {
                Task { await model.delete(file) }
            }
            Button("Cancelar", role: .cancel) {}
        } message: { _ in
            Text(FilesModel.deleteFileMessage)
        }
    }

    /// The dialog titles, from the file that is showing when the person
    /// acts.
    private var zonaTitle: String {
        guard let file = model.viewer?.file else { return "" }
        return FilesModel.zonaConfirmTitle(name: file.name, zona: file.zona)
    }

    private var deleteTitle: String {
        guard let file = model.viewer?.file else { return "" }
        return FilesModel.deleteFileTitle(name: file.name)
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
        .overlay {
            if viewer.files.count > 1 {
                HStack {
                    nav(false, viewer: viewer)
                    Spacer()
                    nav(true, viewer: viewer)
                }
            }
        }
    }

    /// The web's prev/next arrows, for the hand the swipe misses. Dead at
    /// the ends, gone when there is nothing to move through.
    private func nav(_ forward: Bool, viewer: GalleryModel.Viewer) -> some View {
        let reachable = forward ? viewer.index < viewer.files.count - 1 : viewer.index > 0
        return Button {
            model.moveViewer(to: viewer.index + (forward ? 1 : -1))
        } label: {
            Image(systemName: forward ? "chevron.right" : "chevron.left")
                .typeStyle(Theme.Text.h3)
                .foregroundStyle(Theme.Palette.textPrimary)
                .frame(width: Theme.Size.touch, height: Theme.Size.touch)
                .background(Theme.Palette.surfaceScrim, in: Circle())
        }
        .disabled(!reachable)
        .opacity(reachable ? 1 : Theme.Opacity.disabled)
        .padding(.horizontal, Theme.Space.space2)
        .accessibilityLabel(forward ? "Próxima foto" : "Foto anterior")
    }

    @ViewBuilder
    private func page(_ file: File) -> some View {
        if GalleryModel.isVideo(file) {
            GalleryVideo(model: model, file: file)
        } else {
            GalleryImage(rkey: file.rkey)
        }
    }

    /// The bottom bar: the name with its zone, then the actions. The words
    /// are the file screen's for the same acts, so one act reads one way
    /// everywhere.
    @ViewBuilder
    private func caption(_ viewer: GalleryModel.Viewer) -> some View {
        if let file = viewer.file {
            VStack(spacing: 0) {
                HStack(spacing: Theme.Space.space2) {
                    ZonaBadge(zona: file.zona)
                    Text(file.name)
                        .typeStyle(Theme.Text.bodySm)
                        .foregroundStyle(Theme.Palette.textPrimary)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                }
                .padding(.vertical, Theme.Space.space3)
                .padding(.horizontal, Theme.Space.space4)
                actions(file)
            }
            .background(Theme.Palette.surfaceScrimStrong)
        }
    }

    private func actions(_ file: File) -> some View {
        HStack(alignment: .center, spacing: 0) {
            shareButton
            action("Detalhes", icon: "info.circle") {
                sheet = .details(file)
            }
            action(
                FilesModel.zonaActionLabel(for: file.zona),
                icon: file.zona == .casa ? "person.2" : "lock"
            ) {
                confirmingZone = true
            }
            action("Excluir", icon: "trash", role: .destructive) {
                confirmingDelete = true
            }
        }
        .disabled(model.working || sharing)
        .padding(.bottom, Theme.Space.space2)
    }

    private var shareButton: some View {
        Button {
            guard let file = model.viewer?.file else { return }
            Task { await share(file) }
        } label: {
            VStack(spacing: Theme.Space.space1) {
                if sharing {
                    ProgressView()
                        .tint(Theme.Palette.textPrimary)
                } else {
                    Image(systemName: "square.and.arrow.up")
                }
                Text("Compartilhar")
                    .typeStyle(Theme.Text.caption)
            }
            .typeStyle(Theme.Text.h3)
            .foregroundStyle(Theme.Palette.textPrimary)
            .frame(maxWidth: .infinity, minHeight: Theme.Size.touch)
        }
    }

    private func action(_ title: String, icon: String, role: ButtonRole? = nil, action: @escaping () -> Void) -> some View {
        Button(role: role, action: action) {
            VStack(spacing: Theme.Space.space1) {
                Image(systemName: icon)
                Text(title)
                    .typeStyle(Theme.Text.caption)
            }
            .typeStyle(Theme.Text.h3)
            .foregroundStyle(role == .destructive ? Theme.Palette.feedbackError : Theme.Palette.textPrimary)
            .frame(maxWidth: .infinity, minHeight: Theme.Size.touch)
        }
    }

    /// Downloads once, then hands the local file to the system sheet: the
    /// person picks where it goes, the Photos app included.
    private func share(_ file: File) async {
        sharing = true
        let result = await model.download(file)
        if case .success(let url) = result {
            sheet = .share(url)
        }
        sharing = false
    }
}

/// The details sheet, the web's photo-details modal: the zone first (the
/// product's promise, legible where the content lives), then the facts.
struct GalleryDetails: View {
    let file: File

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Space.space4) {
                Text("Detalhes")
                    .typeStyle(Theme.Text.h3)
                    .foregroundStyle(Theme.Palette.textPrimary)
                zone
                row("Nome original", file.name)
                row("Tipo", GalleryModel.humanType(file.mime))
                row("Tamanho", Format.bytes(file.size))
                row("Enviado em", Format.date(file.createdAt))
                signature
            }
            .padding(Theme.Space.space5)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Theme.Palette.bgApp)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private var zone: some View {
        VStack(alignment: .leading, spacing: Theme.Space.space1) {
            Text("Zona")
                .typeStyle(Theme.Text.overline)
                .foregroundStyle(Theme.Palette.textMuted)
            ZonaBadge(zona: file.zona)
            Text(GalleryModel.zoneSentence(file.zona))
                .typeStyle(Theme.Text.caption)
                .foregroundStyle(Theme.Palette.textMuted)
        }
    }

    private func row(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.space1) {
            Text(label)
                .typeStyle(Theme.Text.overline)
                .foregroundStyle(Theme.Palette.textMuted)
            Text(value)
                .typeStyle(Theme.Text.body)
                .foregroundStyle(Theme.Palette.textPrimary)
                .textSelection(.enabled)
        }
    }

    private var signature: some View {
        VStack(alignment: .leading, spacing: Theme.Space.space1) {
            Text("Assinatura do arquivo")
                .typeStyle(Theme.Text.overline)
                .foregroundStyle(Theme.Palette.textMuted)
            Text(file.sha256)
                .typeStyle(Theme.Text.monoSm)
                .foregroundStyle(Theme.Palette.textPrimary)
                .lineLimit(2)
                .textSelection(.enabled)
            Text("É como o Tainá confere que o arquivo está intacto.")
                .typeStyle(Theme.Text.caption)
                .foregroundStyle(Theme.Palette.textMuted)
        }
    }
}

/// The system share sheet over the downloaded file. UIKit's controller,
/// since a ShareLink cannot open itself after a download.
private struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
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

#Preview("Fotos, filtro na praça") {
    PreviewHost(make: {
        let session = await SessionModel.previewSignedIn()
        let model = GalleryModel(api: session.api, session: session)
        model.select(GalleryModel.Filter.praca)
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

#Preview("Fotos, vídeo no visualizador") {
    PreviewHost(make: {
        let session = await SessionModel.previewSignedIn()
        let model = GalleryModel(api: session.api, session: session)
        if case .success(let page) = await session.api.photos(limit: nil, cursor: nil),
           let video = page.items.first(where: { GalleryModel.isVideo($0) }) {
            model.open(video)
        }
        return (session: session, model: model)
    }) { pair in
        GalleryContent(model: pair.model)
            .environment(pair.session)
    }
}
#endif
