import OkenaCore
import SwiftUI

/// The home: the greeting and the community's name, the storage card, the
/// recent uploads and two teasers (the mural and the access requests),
/// mirroring the web's `home_live`. The rows are read-only for now: the
/// navigation lands later.
struct HomeView: View {
    @Environment(SessionModel.self) private var session
    @State private var model: HomeModel?

    var body: some View {
        Group {
            if let model, model.loaded {
                content(model)
            } else {
                LoadingView()
            }
        }
        .background(Theme.Palette.bgApp)
        // The greeting block is the title of this screen; the bar stays out
        // of the way.
        .navigationTitle("Início")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if model == nil {
                model = HomeModel(api: session.api, session: session)
            }
            await model?.load()
        }
    }

    private func content(_ model: HomeModel) -> some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: Theme.Space.space6) {
                header
                storageSection(model)
                recentSection(model)
                muralSection(model)
                requestsSection(model)
            }
            .padding(Theme.Space.space4)
        }
        .refreshable { await model.load() }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: Theme.Space.space1) {
            Text(HomeModel.greeting(hour: Calendar.current.component(.hour, from: Date.now)))
                .typeStyle(Theme.Text.body)
                .foregroundStyle(Theme.Palette.textSecondary)
            if let name = communityName {
                Text(name)
                    .typeStyle(Theme.Text.h1)
                    .foregroundStyle(Theme.Palette.textPrimary)
            }
        }
    }

    private var communityName: String? {
        if case .ready(let me) = session.state {
            return me.tekoa.name
        }
        return session.instance?.tekoa?.name
    }

    // MARK: sections

    @ViewBuilder
    private func storageSection(_ model: HomeModel) -> some View {
        if let stats = model.stats {
            storageCard(stats)
        } else if model.statsError {
            degradedCard("Não foi possível consultar o espaço da comunidade agora.") {
                await model.retryStorage()
            }
        }
    }

    private func recentSection(_ model: HomeModel) -> some View {
        section("Recentes") {
            if let error = model.recentError {
                ErrorView(error: error, retry: { await model.load() })
            } else if model.recent.isEmpty {
                EmptyStateView(
                    systemImage: "tray.and.arrow.up",
                    title: "Nada por aqui ainda",
                    message: "Envie o primeiro arquivo da comunidade."
                )
            } else {
                VStack(spacing: Theme.Space.space2) {
                    ForEach(model.recent, id: \.rkey) { file in
                        RecentRow(file: file)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func muralSection(_ model: HomeModel) -> some View {
        if model.muralError {
            section("Mural") {
                degradedCard("Não foi possível carregar o mural agora.") {
                    await model.load()
                }
            }
        } else if !model.mural.isEmpty {
            section("Mural") {
                VStack(spacing: Theme.Space.space2) {
                    ForEach(model.mural) { line in
                        MuralRow(line: line)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func requestsSection(_ model: HomeModel) -> some View {
        if model.requestsError {
            degradedCard("Não foi possível consultar os pedidos de acesso agora.") {
                await model.load()
            }
        } else if let count = model.pendingRequests {
            requestsCard(count)
        }
    }

    // MARK: pieces

    private func section(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.space3) {
            Text(title)
                .typeStyle(Theme.Text.overline)
                .foregroundStyle(Theme.Palette.textMuted)
            content()
        }
    }

    /// The storage card: use against the quota, with the free space in
    /// words. Without a quota there is no "free" to measure, so the card
    /// shows only the use and hides the bar.
    private func storageCard(_ stats: StorageStats) -> some View {
        RowCard {
            VStack(alignment: .leading, spacing: Theme.Space.space3) {
                HStack {
                    Text("Espaço da comunidade")
                        .typeStyle(Theme.Text.label)
                        .foregroundStyle(Theme.Palette.textPrimary)
                    Spacer()
                    if HomeModel.hasQuota(stats) {
                        HStack(spacing: Theme.Space.space1) {
                            if HomeModel.storageLow(stats) {
                                Image(systemName: "exclamationmark.triangle")
                            }
                            Text(HomeModel.freeLabel(stats))
                        }
                        .typeStyle(Theme.Text.caption)
                        .foregroundStyle(
                            HomeModel.storageLow(stats)
                                ? Theme.Palette.feedbackWarning
                                : Theme.Palette.feedbackSuccess
                        )
                    }
                }
                if HomeModel.hasQuota(stats) {
                    ProgressView(value: Double(HomeModel.storagePercent(stats)) / 100)
                        .tint(Theme.Palette.brandPrimary)
                }
                if let quota = stats.quotaBytes, quota > 0 {
                    Text("\(Format.bytes(stats.usedBytes)) de \(Format.bytes(quota)) usados")
                        .typeStyle(Theme.Text.monoSm)
                        .foregroundStyle(Theme.Palette.textMuted)
                } else {
                    Text("\(Format.bytes(stats.usedBytes)) em uso")
                        .typeStyle(Theme.Text.monoSm)
                        .foregroundStyle(Theme.Palette.textMuted)
                }
            }
        }
    }

    private func requestsCard(_ count: Int) -> some View {
        RowCard {
            HStack(spacing: Theme.Space.space3) {
                Image(systemName: "tray.full")
                    .typeStyle(Theme.Text.h3)
                    .foregroundStyle(Theme.Palette.serviceMaraca)
                    .frame(width: Theme.Space.space10, height: Theme.Space.space10)
                    .background(Theme.Palette.surfaceRaised, in: RoundedRectangle(cornerRadius: Theme.Radius.md))
                VStack(alignment: .leading, spacing: Theme.Space.space1) {
                    Text("Pedidos de acesso")
                        .typeStyle(Theme.Text.label)
                        .foregroundStyle(Theme.Palette.textPrimary)
                    Text(HomeModel.pendingLabel(count))
                        .typeStyle(Theme.Text.caption)
                        .foregroundStyle(Theme.Palette.textMuted)
                }
            }
        }
    }

    /// The calm card that takes the place of a section the box did not
    /// answer: a sentence and a way back, never a card that vanishes.
    private func degradedCard(_ message: String, retry: @escaping () async -> Void) -> some View {
        RowCard {
            VStack(alignment: .leading, spacing: Theme.Space.space3) {
                Text(message)
                    .typeStyle(Theme.Text.bodySm)
                    .foregroundStyle(Theme.Palette.textMuted)
                SecondaryButton(title: "Tentar de novo") {
                    Task { await retry() }
                }
            }
        }
    }
}

/// The glyph of a kind of file, the web's `service_square`: color and shape
/// together, never the color alone.
struct FileGlyph: View {
    let mime: String

    var body: some View {
        Image(systemName: symbol)
            .typeStyle(Theme.Text.h3)
            .foregroundStyle(tint)
            .frame(width: Theme.Space.space10, height: Theme.Space.space10)
            .background(fill, in: RoundedRectangle(cornerRadius: Theme.Radius.md))
    }

    private var symbol: String {
        if mime.hasPrefix("image/") { return "photo" }
        if mime.hasPrefix("audio/") { return "play" }
        return "doc"
    }

    private var tint: Color {
        if mime.hasPrefix("image/") { return Theme.Palette.serviceJaciTint }
        if mime.hasPrefix("video/") || mime.hasPrefix("audio/") { return Theme.Palette.serviceVideo }
        if mime == "application/pdf" { return Theme.Palette.brandEmber }
        if mime.hasPrefix("text/") { return Theme.Palette.serviceYbiraTint }
        return Theme.Palette.textMuted
    }

    private var fill: Color {
        if mime.hasPrefix("image/") { return Theme.Palette.serviceJaciSoft }
        if mime.hasPrefix("text/") { return Theme.Palette.serviceYbiraSoft }
        return Theme.Palette.surfaceRaised
    }
}

/// The recent row: the kind glyph, the name, and the meta line that ends
/// in the zone in words ("Imagem, 2,4 MB, ontem, na praça").
struct RecentRow: View {
    let file: File

    var body: some View {
        RowCard {
            HStack(spacing: Theme.Space.space3) {
                FileGlyph(mime: file.mime)
                VStack(alignment: .leading, spacing: Theme.Space.space1) {
                    Text(file.name)
                        .typeStyle(Theme.Text.label)
                        .foregroundStyle(Theme.Palette.textPrimary)
                        .lineLimit(1)
                        .multilineTextAlignment(.leading)
                    Text(HomeModel.recentMeta(file))
                        .typeStyle(Theme.Text.caption)
                        .foregroundStyle(Theme.Palette.textMuted)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
                Spacer()
            }
        }
    }
}

/// One mural teaser line: the sentence and when it happened.
struct MuralRow: View {
    let line: HomeModel.MuralLine

    var body: some View {
        RowCard {
            VStack(alignment: .leading, spacing: Theme.Space.space2) {
                Text(line.sentence)
                    .typeStyle(Theme.Text.bodySm)
                    .foregroundStyle(Theme.Palette.textPrimary)
                Text(line.ago)
                    .typeStyle(Theme.Text.caption)
                    .foregroundStyle(Theme.Palette.textMuted)
            }
        }
    }
}

#if DEBUG
#Preview("Início") {
    PreviewHost(make: { await SessionModel.previewSignedIn() }) { session in
        HomeView()
            .environment(session)
    }
}
#endif
