import OkenaCore
import SwiftUI

/// The vault's size: used against the quota, broken down by kind, with the
/// counts and what the trash holds. Read only, for every morador.
struct StorageView: View {
    @Environment(SessionModel.self) private var session
    @State private var model: StorageModel?

    var body: some View {
        Group {
            if let model {
                StoragePanel(model: model)
            } else {
                LoadingView()
            }
        }
        .navigationTitle("Armazenamento")
        .task {
            if model == nil {
                model = StorageModel(api: session.api, session: session)
            }
        }
    }
}

/// The panel: one load, the math from the model's pure helpers.
struct StoragePanel: View {
    let model: StorageModel

    @State private var showingQuota = false
    @State private var flash: String?

    var body: some View {
        Group {
            if let stats = model.stats {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: Theme.Space.space5) {
                        usageCard(stats)
                        Text("Só entra o que está na praça, a sua casa e o que te deixarem ver. A casa dos outros fica de fora.")
                            .typeStyle(Theme.Text.caption)
                            .foregroundStyle(Theme.Palette.textMuted)
                        kindList(stats)
                        Text("Soma do que você vê: \(Format.bytes(StorageModel.byKindTotal(stats)))")
                            .typeStyle(Theme.Text.caption)
                            .foregroundStyle(Theme.Palette.textMuted)
                        counts(stats)
                        if model.isZelador {
                            quotaCard(stats)
                        }
                    }
                    .padding(Theme.Space.space4)
                }
            } else if let error = model.error {
                ErrorView(error: error, retry: { await model.load() })
            } else {
                LoadingView()
            }
        }
        .background(Theme.Palette.bgApp)
        .task { await model.load() }
        .refreshable { await model.load() }
        .sheet(isPresented: $showingQuota) {
            QuotaSheet(model: model) { result in
                if case .failure(let error) = result {
                    flash = error.errorDescription ?? "Não deu certo salvar o limite. Tente de novo."
                }
            }
        }
        .alert(
            "Não deu certo",
            isPresented: Binding(
                get: { flash != nil },
                set: { if !$0 { flash = nil } }
            ),
            presenting: flash
        ) { _ in
            Button("Entendi", role: .cancel) {}
        } message: { message in
            Text(message)
        }
    }

    /// The big card: the used bytes, the quota line, the bar by kind.
    private func usageCard(_ stats: StorageStats) -> some View {
        RowCard {
            VStack(alignment: .leading, spacing: Theme.Space.space2) {
                Text("Espaço da comunidade")
                    .typeStyle(Theme.Text.overline)
                    .foregroundStyle(Theme.Palette.textMuted)
                Text(Format.bytes(stats.usedBytes))
                    .typeStyle(Theme.Text.display)
                    .font(.custom(Theme.Fonts.mono, size: Theme.Text.fontSizeDisplay, relativeTo: .largeTitle).weight(.bold))
                    .foregroundStyle(Theme.Palette.textPrimary)
                quotaLine(stats)
                UsageBar(segments: StorageModel.segments(stats))
                Text("Uso por tipo")
                    .typeStyle(Theme.Text.caption)
                    .foregroundStyle(Theme.Palette.textMuted)
            }
        }
    }

    /// "de X usados" with the free room beside it, or the absence of a
    /// limit said as a state. The color never works alone: the word "livres"
    /// carries the meaning, the color only underlines it. A limit set
    /// below the use says so, instead of a negative number of livres.
    private func quotaLine(_ stats: StorageStats) -> some View {
        HStack {
            if let quota = stats.quotaBytes {
                Text("de \(Format.bytes(quota)) usados")
                    .typeStyle(Theme.Text.bodySm)
                    .foregroundStyle(Theme.Palette.textMuted)
                Spacer()
                if StorageModel.isOverQuota(stats) {
                    Text("O limite está abaixo do que já está guardado.")
                        .typeStyle(Theme.Text.bodySm)
                        .foregroundStyle(Theme.Palette.feedbackWarning)
                        .multilineTextAlignment(.trailing)
                } else {
                    Text("\(Format.bytes(quota - stats.usedBytes)) livres")
                        .typeStyle(Theme.Text.bodySm)
                        .foregroundStyle(
                            StorageModel.isLowFree(stats) ? Theme.Palette.feedbackWarning : Theme.Palette.feedbackSuccess
                        )
                }
            } else {
                Text("Sem limite definido.")
                    .typeStyle(Theme.Text.bodySm)
                    .foregroundStyle(Theme.Palette.textMuted)
            }
        }
    }

    /// The zeladora's limit card: the number as it stands and the way to
    /// change it. The act is the box's to accept or refuse.
    private func quotaCard(_ stats: StorageStats) -> some View {
        RowCard {
            VStack(alignment: .leading, spacing: Theme.Space.space2) {
                Text("Limite da comunidade")
                    .typeStyle(Theme.Text.overline)
                    .foregroundStyle(Theme.Palette.textMuted)
                if let quota = stats.quotaBytes {
                    Text("\(Format.bytes(quota)) por mês de espaço para os arquivos de todo mundo.")
                        .typeStyle(Theme.Text.bodySm)
                        .foregroundStyle(Theme.Palette.textSecondary)
                } else {
                    Text("Nenhum limite definido. A caixa usa o espaço que o disco tem.")
                        .typeStyle(Theme.Text.bodySm)
                        .foregroundStyle(Theme.Palette.textSecondary)
                }
                SecondaryButton(title: "Mudar o limite") {
                    showingQuota = true
                }
            }
        }
    }

    private func kindList(_ stats: StorageStats) -> some View {
        VStack(spacing: Theme.Space.space2) {
            ForEach(StorageModel.kinds(stats)) { line in
                RowCard {
                    HStack(spacing: Theme.Space.space3) {
                        Circle()
                            .fill(UsageBar.color(for: line.kind))
                            .frame(width: Theme.Size.navDot, height: Theme.Size.navDot)
                        Text(line.kind.label)
                            .typeStyle(Theme.Text.body)
                            .foregroundStyle(Theme.Palette.textPrimary)
                        Spacer()
                        Text(Format.bytes(line.bytes))
                            .typeStyle(Theme.Text.monoSm)
                            .foregroundStyle(Theme.Palette.textPrimary)
                    }
                }
            }
        }
    }

    private func counts(_ stats: StorageStats) -> some View {
        VStack(spacing: Theme.Space.space2) {
            countRow(icon: "folder", label: "Arquivos", value: "\(stats.files)")
            countRow(icon: "photo", label: "Fotos", value: "\(stats.photos)")
            countRow(icon: "trash", label: "Lixeira", value: StorageModel.trashSummary(stats.trash))
        }
    }

    private func countRow(icon: String, label: String, value: String) -> some View {
        RowCard {
            HStack(spacing: Theme.Space.space3) {
                Image(systemName: icon)
                    .typeStyle(Theme.Text.body)
                    .foregroundStyle(Theme.Palette.serviceYbira)
                Text(label)
                    .typeStyle(Theme.Text.body)
                    .foregroundStyle(Theme.Palette.textPrimary)
                Spacer()
                Text(value)
                    .typeStyle(Theme.Text.monoSm)
                    .foregroundStyle(Theme.Palette.textPrimary)
            }
        }
    }
}

/// The segmented bar: one fill per kind with bytes, widest first, on a
/// quiet track. The height is the progress token, the colors the same the
/// legend rows use.
struct UsageBar: View {
    var segments: [StorageModel.Segment]

    var body: some View {
        GeometryReader { geo in
            HStack(spacing: 0) {
                ForEach(segments) { segment in
                    Rectangle()
                        .fill(Self.color(for: segment.kind))
                        .frame(width: segment.fraction * geo.size.width)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.sm))
            .background(Theme.Palette.surfaceHigh, in: RoundedRectangle(cornerRadius: Theme.Radius.sm))
        }
        .frame(height: Theme.Size.progress)
    }

    /// The sanctioned colors of the web bar and its legend: fotos in Jaci,
    /// videos in sky, documents in Ybira, the rest neutral.
    static func color(for kind: StorageKind) -> Color {
        switch kind {
        case .photos: Theme.Palette.serviceJaci
        case .videos: Theme.Palette.serviceVideo
        case .documents: Theme.Palette.serviceYbira
        case .others: Theme.Palette.textFaint
        }
    }
}

/// The zeladora's limit form: whole gigabytes, the number the box's
/// quota card speaks. Below the current use is allowed and said on the
/// spot; the box has the last word.
struct QuotaSheet: View {
    let model: StorageModel
    let outcome: (TainaResult<Void>) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    @State private var saving = false

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.space4) {
            Text("Mudar o limite")
                .typeStyle(Theme.Text.h3)
                .foregroundStyle(Theme.Palette.textPrimary)
            Text("O espaço total da comunidade, em gigabytes. A lixeira conta até a limpeza passar.")
                .typeStyle(Theme.Text.bodySm)
                .foregroundStyle(Theme.Palette.textSecondary)
            TainaField(
                label: "Gigabytes",
                text: $text,
                keyboard: .numberPad,
                placeholder: "250",
                help: help
            )
            if let warning {
                Text(warning)
                    .typeStyle(Theme.Text.caption)
                    .foregroundStyle(Theme.Palette.feedbackWarning)
            }
            PrimaryButton(title: "Salvar", loading: saving) {
                Task { await save() }
            }
            .disabled(!valid || saving)
            SecondaryButton(title: "Cancelar") { dismiss() }
        }
        .padding(Theme.Space.space5)
        .presentationDetents([.medium])
        .task {
            if text.isEmpty {
                text = String(StorageModel.gigabytes(model.stats?.quotaBytes))
            }
        }
    }

    private var gigabytes: Int64? {
        guard let parsed = Int64(text.trimmingCharacters(in: .whitespaces)), parsed >= 1 else {
            return nil
        }
        return parsed
    }

    private var valid: Bool {
        gigabytes != nil
    }

    private var warning: String? {
        guard let gigabytes, let used = model.stats?.usedBytes else { return nil }
        let bytes = StorageModel.bytes(fromGigabytes: gigabytes)
        return bytes < used ? "Este limite é menor do que já está guardado. Nada é apagado; a caixa só não aceita mais nada até o limite subir." : nil
    }

    private var help: String {
        "Por exemplo: 250"
    }

    private func save() async {
        guard let gigabytes else { return }
        saving = true
        defer { saving = false }
        let result = await model.setQuota(bytes: StorageModel.bytes(fromGigabytes: gigabytes))
        switch result {
        case .success:
            dismiss()
        case .failure:
            break
        }
        outcome(result)
    }
}

#if DEBUG
#Preview("Armazenamento") {
    PreviewHost(make: { await SessionModel.previewSignedIn() }) { session in
        StorageView()
            .environment(session)
    }
}
#endif
