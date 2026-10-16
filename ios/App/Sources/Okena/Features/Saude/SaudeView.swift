import OkenaCore
import SwiftUI

/// The box's health, in sentences a person reads: the disk, the last backup
/// and the queued work. Read only, for every morador; the machine's own
/// panel is the zelador's and stays on the web.
struct SaudeView: View {
    @Environment(SessionModel.self) private var session
    @State private var model: SaudeModel?

    var body: some View {
        Group {
            if let model {
                SaudePanel(model: model)
            } else {
                LoadingView()
            }
        }
        .navigationTitle("Saúde da comunidade")
        .task {
            if model == nil {
                model = SaudeModel(api: session.api, session: session)
            }
        }
    }
}

/// The panel itself: one load, the rows from the model's pure builders.
struct SaudePanel: View {
    let model: SaudeModel

    var body: some View {
        Group {
            if let saude = model.saude {
                ScrollView {
                    LazyVStack(spacing: Theme.Space.space3) {
                        ForEach(SaudeModel.rows(from: saude)) { row in
                            RowCard {
                                SaudeRowView(row: row)
                            }
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
    }
}

/// One row: the icon and the label, the facts as lines, the warning when
/// the fact needs one.
struct SaudeRowView: View {
    let row: SaudeModel.Row

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.space2) {
            HStack(spacing: Theme.Space.space3) {
                Image(systemName: row.icon)
                    .typeStyle(Theme.Text.body)
                    .foregroundStyle(Theme.Palette.textMuted)
                Text(row.label)
                    .typeStyle(Theme.Text.label)
                    .foregroundStyle(Theme.Palette.textPrimary)
            }
            ForEach(row.lines, id: \.self) { line in
                Text(line)
                    .typeStyle(Theme.Text.bodySm)
                    .foregroundStyle(Theme.Palette.textSecondary)
            }
            if let warning = row.warning {
                HStack(alignment: .top, spacing: Theme.Space.space2) {
                    Image(systemName: "exclamationmark.triangle")
                        .typeStyle(Theme.Text.caption)
                    Text(warning)
                        .typeStyle(Theme.Text.bodySm)
                }
                .foregroundStyle(Theme.Palette.feedbackWarning)
            }
        }
    }
}

#if DEBUG
#Preview("Saúde da comunidade") {
    PreviewHost(make: { await SessionModel.previewSignedIn() }) { session in
        SaudeView()
            .environment(session)
    }
}
#endif
