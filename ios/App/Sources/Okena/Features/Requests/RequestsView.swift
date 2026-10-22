import OkenaCore
import SwiftUI

/// The pedidos screen (Conta -> Pedidos on the web): what the community
/// asked of this person and what this person asked of others, one segmented
/// screen. The dono decides; a decided pedido leaves the pending list and
/// the outcome is said out loud, never silent.
struct RequestsView: View {
    @Environment(SessionModel.self) private var session
    @State private var model: RequestsModel?

    var body: some View {
        Group {
            if let model {
                RequestsList(model: model)
            } else {
                LoadingView()
            }
        }
        .navigationTitle("Pedidos")
        .task {
            if model == nil {
                model = RequestsModel(api: session.api, session: session)
            }
        }
    }
}

/// The status of a pedido, in words and in color, wherever a row shows it.
extension PedidoStatus {
    var label: String {
        switch self {
        case .pendente: "Pendente"
        case .aprovado: "Aprovado"
        case .negado: "Negado"
        }
    }

    var color: Color {
        switch self {
        case .pendente: Theme.Palette.feedbackWarning
        case .aprovado: Theme.Palette.feedbackSuccess
        case .negado: Theme.Palette.feedbackError
        }
    }
}

private struct Flash {
    var title: String
    var message: String
}

/// One segmented screen, two lists of pedidos and the accesses of both
/// sides, one loading logic: the model's pure transitions, the shell's
/// thin callbacks.
struct RequestsList: View {
    let model: RequestsModel

    private enum Tab {
        case received, sent, granted
    }

    @State private var tab: Tab = .received
    @State private var denying: Pedido?
    @State private var revoking: Concessao?
    @State private var flash: Flash?

    var body: some View {
        VStack(spacing: 0) {
            Picker("Pedidos", selection: $tab) {
                Text("Recebidos").tag(Tab.received)
                Text("Enviados").tag(Tab.sent)
                Text("Acessos").tag(Tab.granted)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, Theme.Space.space4)
            .padding(.vertical, Theme.Space.space3)
            switch tab {
            case .received:
                section(model.sections.received, empty: receivedEmpty, rows: receivedRows)
            case .sent:
                section(model.sections.sent, empty: sentEmpty, rows: sentRows)
            case .granted:
                grantedSections
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Theme.Palette.bgApp)
        // Loads on appear and on pull: the screen owns its own loading.
        .task { await model.load() }
        .refreshable { await model.load() }
        .confirmationDialog(
            "Negar este pedido?",
            isPresented: Binding(
                get: { denying != nil },
                set: { if !$0 { denying = nil } }
            ),
            titleVisibility: .visible,
            presenting: denying
        ) { pedido in
            Button("Negar", role: .destructive) {
                Task { await deny(pedido) }
            }
            Button("Cancelar", role: .cancel) {}
        } message: { _ in
            Text("A pessoa não vai poder abrir o arquivo. Ela pode pedir de novo depois.")
        }
        .confirmationDialog(
            "Revogar este acesso?",
            isPresented: Binding(
                get: { revoking != nil },
                set: { if !$0 { revoking = nil } }
            ),
            titleVisibility: .visible,
            presenting: revoking
        ) { concessao in
            Button("Revogar", role: .destructive) {
                Task { await revoke(concessao) }
            }
            Button("Cancelar", role: .cancel) {}
        } message: { concessao in
            Text("\(RequestsModel.personLabel(concessao.leitor)) deixa de poder abrir \(RequestsModel.resourceName(for: concessao, in: model.grantNames)). A pessoa pode pedir de novo depois.")
        }
        .alert(
            flash?.title ?? "",
            isPresented: Binding(
                get: { flash != nil },
                set: { if !$0 { flash = nil } }
            ),
            presenting: flash
        ) { _ in
            Button("Entendi", role: .cancel) {}
        } message: { presented in
            Text(presented.message)
        }
    }

    // MARK: sections

    /// The states of one list, as the browser shows them: loading while
    /// nothing arrived, the error with a way out, the honest empty, or the
    /// rows.
    @ViewBuilder
    private func section(_ pedidos: [Pedido], empty: EmptyStateView, rows: () -> some View) -> some View {
        if pedidos.isEmpty {
            if model.loading {
                LoadingView()
            } else if let error = model.error {
                ErrorView(error: error, retry: { await model.load() })
            } else {
                empty
            }
        } else {
            ScrollView {
                LazyVStack(spacing: Theme.Space.space2) {
                    rows()
                }
                .padding(Theme.Space.space4)
            }
        }
    }

    /// The accesses: two lists on one scroll, the ones given with the
    /// revoke on the standing rows, the ones received read only.
    @ViewBuilder
    private var grantedSections: some View {
        if model.grants.given.isEmpty && model.grants.received.isEmpty {
            if model.loading {
                LoadingView()
            } else if let error = model.error {
                ErrorView(error: error, retry: { await model.load() })
            } else {
                grantedEmpty
            }
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: Theme.Space.space2) {
                    overline("Você liberou")
                    ForEach(model.grants.given, id: \.publicId) { concessao in
                        GrantRow(
                            person: RequestsModel.personLabel(concessao.leitor),
                            resource: RequestsModel.resourceName(for: concessao, in: model.grantNames),
                            revoked: RequestsModel.isRevoked(concessao),
                            date: concessao.revogadaEm ?? concessao.concedidaEm ?? concessao.createdAt,
                            revoking: model.revoking == concessao.publicId,
                            onRevoke: RequestsModel.isRevoked(concessao) ? nil : { revoking = concessao }
                        )
                    }
                    if model.grants.given.isEmpty {
                        Text("Nenhum acesso liberado por enquanto. Quando você aprovar um pedido, ele vira um acesso aqui.")
                            .typeStyle(Theme.Text.bodySm)
                            .foregroundStyle(Theme.Palette.textMuted)
                    }
                    overline("Liberados para você")
                    ForEach(model.grants.received, id: \.publicId) { concessao in
                        GrantRow(
                            person: RequestsModel.personLabel(concessao.dono),
                            resource: RequestsModel.resourceName(for: concessao, in: model.grantNames),
                            revoked: RequestsModel.isRevoked(concessao),
                            date: concessao.revogadaEm ?? concessao.concedidaEm ?? concessao.createdAt
                        )
                    }
                    if model.grants.received.isEmpty {
                        Text("Nenhum ainda. Quando alguém te deixar ler um arquivo, o acesso aparece aqui.")
                            .typeStyle(Theme.Text.bodySm)
                            .foregroundStyle(Theme.Palette.textMuted)
                    }
                }
                .padding(Theme.Space.space4)
            }
        }
    }

    private func overline(_ title: String) -> some View {
        Text(title)
            .typeStyle(Theme.Text.overline)
            .foregroundStyle(Theme.Palette.textMuted)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var grantedEmpty: EmptyStateView {
        EmptyStateView(
            systemImage: "key",
            title: "Nenhum acesso por enquanto",
            message: "Quando você aprovar um pedido, ele vira um acesso aqui, e você pode revogar depois. Os que você recebeu também aparecem."
        )
    }

    private var receivedEmpty: EmptyStateView {
        EmptyStateView(
            systemImage: "shield",
            title: "Nenhum pedido por enquanto",
            message: "Ninguém acessa seus arquivos sem você deixar. Quando alguém pedir, aparece aqui."
        )
    }

    private var sentEmpty: EmptyStateView {
        EmptyStateView(
            systemImage: "paperplane",
            title: "Você não pediu acesso a nada",
            message: "Quando você pedir para abrir um arquivo de outra pessoa, o pedido aparece aqui até ela decidir."
        )
    }

    @ViewBuilder
    private func receivedRows() -> some View {
        Text(RequestsModel.receivedHeader(count: model.sections.received.count))
            .typeStyle(Theme.Text.overline)
            .foregroundStyle(Theme.Palette.textMuted)
            .frame(maxWidth: .infinity, alignment: .leading)
        ForEach(model.sections.received, id: \.publicId) { pedido in
            PedidoRow(
                person: RequestsModel.personLabel(pedido.pedinte),
                status: pedido.status,
                resource: RequestsModel.resourceLine(
                    received: true,
                    name: RequestsModel.resourceName(for: pedido, in: model.receivedNames)
                ),
                motivo: pedido.motivo,
                date: pedido.decididoEm ?? pedido.createdAt,
                deciding: model.deciding == pedido.publicId,
                onApprove: { Task { await approve(pedido) } },
                onDeny: { denying = pedido }
            )
        }
    }

    @ViewBuilder
    private func sentRows() -> some View {
        ForEach(model.sections.sent, id: \.publicId) { pedido in
            PedidoRow(
                person: RequestsModel.personLabel(pedido.dono),
                status: pedido.status,
                resource: RequestsModel.resourceLine(
                    received: false,
                    name: RequestsModel.resourceName(for: pedido, in: model.sentNames)
                ),
                motivo: pedido.motivo,
                date: pedido.decididoEm ?? pedido.createdAt
            )
        }
    }

    // MARK: decisions

    private func approve(_ pedido: Pedido) async {
        let name = model.receivedNames[pedido.recurso]
        let result = await model.approve(id: pedido.publicId)
        flash = Self.outcome("Pedido aprovado", result: result, success: RequestsModel.approvedMessage(named: name))
    }

    private func deny(_ pedido: Pedido) async {
        let result = await model.deny(id: pedido.publicId)
        flash = Self.outcome("Pedido negado", result: result, success: "A pessoa pode pedir de novo quando quiser.")
    }

    private func revoke(_ concessao: Concessao) async {
        let name = model.grantNames[concessao.recurso]
        let result = await model.revoke(id: concessao.publicId)
        flash = Self.outcome("Acesso revogado", result: result, success: RequestsModel.revokedMessage(named: name))
    }

    /// The one alert slot: a decision said out loud, or the failure's own
    /// pt-BR sentence.
    private static func outcome(_ title: String, result: TainaResult<Void>, success message: String) -> Flash {
        switch result {
        case .success:
            Flash(title: title, message: message)
        case .failure(let error):
            Flash(title: "Não deu certo", message: error.errorDescription ?? "Algo deu errado. Tente de novo.")
        }
    }
}

/// One pedido: the person it is about, the resource, the motivo in full
/// (deciding without the why is deciding blind), the status and the date.
/// The received, still-pending rows also carry the decision.
struct PedidoRow: View {
    let person: String
    let status: PedidoStatus
    let resource: String
    let motivo: String?
    let date: String
    var deciding = false
    var onApprove: (() -> Void)?
    var onDeny: (() -> Void)?
    var body: some View {
        RowCard {
            VStack(alignment: .leading, spacing: Theme.Space.space2) {
                HStack {
                    Text(person)
                        .typeStyle(Theme.Text.label)
                        .foregroundStyle(Theme.Palette.textPrimary)
                        .lineLimit(1)
                    Spacer()
                    Text(status.label)
                        .typeStyle(Theme.Text.caption)
                        .foregroundStyle(status.color)
                }
                Text(resource)
                    .typeStyle(Theme.Text.bodySm)
                    .foregroundStyle(Theme.Palette.textSecondary)
                if let motivo {
                    Text("Motivo: \(motivo)")
                        .typeStyle(Theme.Text.bodySm)
                        .foregroundStyle(Theme.Palette.textMuted)
                }
                Text(Format.relative(date))
                    .typeStyle(Theme.Text.caption)
                    .foregroundStyle(Theme.Palette.textFaint)
                if onApprove != nil || onDeny != nil {
                    HStack(spacing: Theme.Space.space2) {
                        SecondaryButton(title: "Negar") { onDeny?() }
                        PrimaryButton(title: "Aprovar", loading: deciding) { onApprove?() }
                    }
                    .disabled(deciding)
                }
            }
        }
    }
}

/// One granted access: who reads what, standing or revoked, with the
/// revoke on the standing ones the caller gave. Revoking is destructive
/// and says what the person loses; the fact itself stays on the list.
struct GrantRow: View {
    let person: String
    let resource: String
    let revoked: Bool
    let date: String
    var revoking = false
    var onRevoke: (() -> Void)?

    var body: some View {
        RowCard {
            VStack(alignment: .leading, spacing: Theme.Space.space2) {
                HStack {
                    Text(person)
                        .typeStyle(Theme.Text.label)
                        .foregroundStyle(Theme.Palette.textPrimary)
                        .lineLimit(1)
                    Spacer()
                    Text(revoked ? "Revogado" : "Ativo")
                        .typeStyle(Theme.Text.caption)
                        .foregroundStyle(revoked ? Theme.Palette.textMuted : Theme.Palette.feedbackSuccess)
                }
                Text(resource)
                    .typeStyle(Theme.Text.bodySm)
                    .foregroundStyle(Theme.Palette.textSecondary)
                Text(Format.relative(date))
                    .typeStyle(Theme.Text.caption)
                    .foregroundStyle(Theme.Palette.textFaint)
                if let onRevoke {
                    SecondaryButton(title: revoking ? "Revogando..." : "Revogar") { onRevoke() }
                        .disabled(revoking)
                }
            }
        }
    }
}

#if DEBUG
#Preview("Pedidos") {
    PreviewHost(make: { await SessionModel.previewSignedIn() }) { session in
        RequestsView()
            .environment(session)
    }
}
#endif
