import OkenaCore
import SwiftUI

/// The community's people, as the box lists them: zeladoras first. Every
/// morador reads; the acts of the zeladora live on this screen too, one
/// menu per row, so she does her work from the phone.
struct MembersView: View {
    @Environment(SessionModel.self) private var session
    @State private var model: MembersModel?

    var body: some View {
        Group {
            if let model {
                MemberList(model: model)
            } else {
                LoadingView()
            }
        }
        .navigationTitle("Moradores")
        .task {
            if model == nil {
                model = MembersModel(api: session.api, session: session)
            }
        }
    }
}

/// What the sheet shows once a link is minted: title, the link in full,
/// and the rule said out loud. Identifiable for the sheet's item.
private struct LinkSheet: Identifiable {
    let id = UUID()
    let title: String
    let link: String
    let message: String
}

/// One act that deserves a word of caution before it happens.
private enum Pending {
    case deactivate(Ava)
    case revokeInvite(Ava)

    var title: String {
        switch self {
        case .deactivate: "Desativar conta?"
        case .revokeInvite: "Revogar este convite?"
        }
    }

    var primary: String {
        switch self {
        case .deactivate: "Desativar"
        case .revokeInvite: "Revogar"
        }
    }

    var message: String {
        switch self {
        case .deactivate(let member):
            "\(member.label) deixa de entrar na comunidade. O acesso volta quando a conta for reativada."
        case .revokeInvite:
            "O link de convite para de valer. Seria preciso convidar de novo."
        }
    }
}

/// The list itself: loading, empty and failure each have their place, and
/// the pull to refresh reloads through the model.
struct MemberList: View {
    let model: MembersModel

    @State private var showingInvite = false
    @State private var confirming: Pending?
    @State private var sheet: LinkSheet?
    @State private var flash: String?

    var body: some View {
        Group {
            if model.members.isEmpty {
                if model.loading {
                    LoadingView()
                } else if let error = model.error {
                    ErrorView(error: error, retry: { await model.load() })
                } else {
                    EmptyStateView(
                        systemImage: "person.2",
                        title: "Ninguém por aqui",
                        message: "A comunidade ainda não tem moradores."
                    )
                }
            } else {
                list
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Theme.Palette.bgApp)
        .task { await model.load() }
        .refreshable { await model.load() }
        .toolbar {
            if model.isZelador {
                Button {
                    showingInvite = true
                } label: {
                    Image(systemName: "person.badge.plus")
                }
                .accessibilityLabel("Convidar pessoa")
            }
        }
        .sheet(isPresented: $showingInvite) {
            InviteSheet(model: model) { created in
                sheet = LinkSheet(
                    title: "Convite criado",
                    link: created.inviteUrl,
                    message: "Envie este link para a pessoa. Ela abre no Tainá e escolhe o próprio nome de usuário. O link vale uma vez só."
                )
            }
        }
        .sheet(item: $sheet) { link in
            LinkSheetView(sheet: link)
        }
        .confirmationDialog(
            confirming?.title ?? "",
            isPresented: Binding(
                get: { confirming != nil },
                set: { if !$0 { confirming = nil } }
            ),
            titleVisibility: .visible,
            presenting: confirming
        ) { pending in
            Button(pending.primary, role: .destructive) {
                Task { await settle(pending) }
            }
            Button("Cancelar", role: .cancel) {}
        } message: { pending in
            Text(pending.message)
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

    private var list: some View {
        ScrollView {
            LazyVStack(spacing: Theme.Space.space2) {
                Text(MembersModel.countLine(model.members.count))
                    .typeStyle(Theme.Text.overline)
                    .foregroundStyle(Theme.Palette.textMuted)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(hint)
                    .typeStyle(Theme.Text.caption)
                    .foregroundStyle(Theme.Palette.textMuted)
                    .frame(maxWidth: .infinity, alignment: .leading)
                ForEach(model.members, id: \.publicId) { member in
                    RowCard {
                        MemberRow(
                            member: member,
                            mePublicId: model.mePublicId,
                            isZelador: model.isZelador,
                            working: model.working == member.publicId,
                            onChangeRole: { papel in Task { await changeRole(member, to: papel) } },
                            onResetLink: { Task { await resetLink(member) } },
                            onDeactivate: { confirming = .deactivate(member) },
                            onReactivate: { Task { await reactivate(member) } },
                            onRevokeInvite: { confirming = .revokeInvite(member) }
                        )
                    }
                }
            }
            .padding(Theme.Space.space4)
        }
    }

    /// Where the acts live, said out loud: the screen is theirs when the
    /// person is the zeladora, and a window when she is not.
    private var hint: String {
        model.isZelador
            ? "Você cuida da comunidade: convide pelo + no topo, mude papéis e mande o link de senha pelo menu de cada pessoa."
            : "Quem cuida da comunidade convida e muda papéis. Para pedir um convite ou uma senha nova, fale com a zeladora."
    }

    private func changeRole(_ member: Ava, to papel: Papel) async {
        let result = await model.changeRole(id: member.publicId, to: papel)
        flash = Self.outcome(result)
    }

    private func resetLink(_ member: Ava) async {
        switch await model.resetLink(id: member.publicId) {
        case .success(let link):
            sheet = LinkSheet(
                title: "Link de senha",
                link: link.resetUrl,
                message: "Envie este link para \(link.ava.label). Ela escolhe uma senha nova e entra de novo. O link vale uma vez só."
            )
        case .failure(let error):
            flash = Self.outcome(.failure(error) as TainaResult<Void>)
        }
    }

    private func reactivate(_ member: Ava) async {
        let result = await model.reactivate(id: member.publicId)
        flash = Self.outcome(result)
    }

    private func settle(_ pending: Pending) async {
        let result: TainaResult<Void>
        switch pending {
        case .deactivate(let member):
            result = await model.deactivate(id: member.publicId)
        case .revokeInvite(let member):
            result = await model.revokeInvite(id: member.publicId)
        }
        flash = Self.outcome(result)
    }

    /// The one alert slot: the failure's own pt-BR sentence. Success is
    /// said by the list itself, which already shows the new state.
    private static func outcome<Value>(_ result: TainaResult<Value>) -> String? {
        if case .failure(let error) = result {
            return error.errorDescription ?? "Algo deu errado. Tente de novo."
        }
        return nil
    }
}

/// One person: the mark, the name, the role, and the state when there is
/// one (deactivated, or the person holding the phone). The zeladora's
/// acts sit in the menu of the row.
struct MemberRow: View {    let member: Ava
    var mePublicId: String?
    var isZelador = false
    var working = false
    var onChangeRole: ((Papel) -> Void)?
    var onResetLink: (() -> Void)?
    var onDeactivate: (() -> Void)?
    var onReactivate: (() -> Void)?
    var onRevokeInvite: (() -> Void)?

    private var isMe: Bool {
        member.publicId == mePublicId
    }

    var body: some View {
        HStack(spacing: Theme.Space.space3) {
            MemberAvatar(name: member.label, inactive: member.deactivatedAt != nil)
            VStack(alignment: .leading, spacing: Theme.Space.space1) {
                Text(member.label)
                    .typeStyle(Theme.Text.label)
                    .foregroundStyle(Theme.Palette.textPrimary)
                    .lineLimit(1)
                Text(member.papel.label)
                    .typeStyle(Theme.Text.bodySm)
                    .foregroundStyle(Theme.Palette.textSecondary)
                if let meta = MembersModel.meta(for: member, mePublicId: mePublicId) {
                    Text(meta)
                        .typeStyle(Theme.Text.caption)
                        .foregroundStyle(Theme.Palette.textMuted)
                }
            }
            Spacer()
            if isZelador, !isMe {
                menu
            }
        }
    }

    /// The acts one row offers, by the state the person is in: a pending
    /// invite can only be taken back, a deactivated account can come
    /// back, and an active member can change roles, ask for a password
    /// link or be deactivated.
    @ViewBuilder
    private var menu: some View {
        Menu {
            if MembersModel.isPendingInvite(member) {
                Button("Revogar convite", role: .destructive) { onRevokeInvite?() }
            } else if member.deactivatedAt != nil {
                Button("Reativar conta") { onReactivate?() }
            } else {
                switch member.papel {
                case .morador:
                    Button("Tornar zelador(a)") { onChangeRole?(.zelador) }
                case .zelador:
                    Button("Voltar a morador") { onChangeRole?(.morador) }
                }
                Button("Link de senha") { onResetLink?() }
                Button("Desativar conta", role: .destructive) { onDeactivate?() }
            }
        } label: {
            if working {
                ProgressView()
            } else {
                Image(systemName: "ellipsis.circle")
                    .typeStyle(Theme.Text.label)
                    .foregroundStyle(Theme.Palette.textMuted)
            }
        }
        .disabled(working)
        .accessibilityLabel("Ações para \(member.label)")
    }
}

/// The person's mark: the first letter on a deterministic tint, dimmed when
/// the account is not active.
struct MemberAvatar: View {
    let name: String
    var inactive = false

    var body: some View {
        Text(initial)
            .typeStyle(Theme.Text.label)
            .foregroundStyle(inactive ? Theme.Palette.textMuted : Theme.Palette.textPrimary)
            .frame(width: Theme.Size.controlSm, height: Theme.Size.controlSm)
            .background(tint, in: Circle())
    }

    private var initial: String {
        String(name.first ?? " ").uppercased()
    }

    private var tint: Color {
        switch MembersModel.tintIndex(for: name) {
        case 0: Theme.Palette.avatarTint0
        case 1: Theme.Palette.avatarTint1
        case 2: Theme.Palette.avatarTint2
        default: Theme.Palette.avatarTint3
        }
    }
}

/// The sheet a minted link lands in: the link in full, the copy at one
/// touch, and the one-time rule said out loud.
private struct LinkSheetView: View {
    let sheet: LinkSheet

    @Environment(\.dismiss) private var dismiss
    @State private var copied = false

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.space4) {
            Text(sheet.title)
                .typeStyle(Theme.Text.h3)
                .foregroundStyle(Theme.Palette.textPrimary)
            Text(sheet.message)
                .typeStyle(Theme.Text.bodySm)
                .foregroundStyle(Theme.Palette.textSecondary)
            Text(sheet.link)
                .typeStyle(Theme.Text.monoSm)
                .foregroundStyle(Theme.Palette.textPrimary)
                .lineLimit(3)
                .truncationMode(.middle)
                .frame(maxWidth: .infinity, minHeight: Theme.Size.controlSm, alignment: .center)
                .background(Theme.Palette.fieldBg, in: RoundedRectangle(cornerRadius: Theme.Radius.md))
            PrimaryButton(title: copied ? "Copiado" : "Copiar link") {
                UIPasteboard.general.string = sheet.link
                copied = true
            }
            SecondaryButton(title: "Fechar") { dismiss() }
        }
        .padding(Theme.Space.space5)
        .presentationDetents([.medium])
    }
}

/// The invite the zeladora mints: the role of the new person, then the
/// link. The default is morador, like the web's form.
struct InviteSheet: View {
    let model: MembersModel
    let created: (MemberInvite) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var papel: Papel = .morador
    @State private var working = false
    @State private var failure: String?

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.space4) {
            Text("Convidar pessoa")
                .typeStyle(Theme.Text.h3)
                .foregroundStyle(Theme.Palette.textPrimary)
            Text("A pessoa entra pelo link do convite e escolhe o próprio nome de usuário.")
                .typeStyle(Theme.Text.bodySm)
                .foregroundStyle(Theme.Palette.textSecondary)
            Picker("Papel", selection: $papel) {
                Text("Morador").tag(Papel.morador)
                Text("Zelador").tag(Papel.zelador)
            }
            .pickerStyle(.segmented)
            .accessibilityLabel("Papel da pessoa convidada")
            if let failure {
                Text(failure)
                    .typeStyle(Theme.Text.caption)
                    .foregroundStyle(Theme.Palette.feedbackError)
            }
            PrimaryButton(title: "Criar convite", loading: working) {
                Task { await invite() }
            }
            .disabled(working)
            SecondaryButton(title: "Cancelar") { dismiss() }
        }
        .padding(Theme.Space.space5)
        .presentationDetents([.medium])
    }

    private func invite() async {
        working = true
        defer { working = false }
        switch await model.invite(papel: papel) {
        case .success(let minted):
            created(minted)
            dismiss()
        case .failure(let error):
            failure = error.errorDescription ?? "Não deu certo criar o convite. Tente de novo."
        }
    }
}

#if DEBUG
#Preview("Moradores") {
    PreviewHost(make: { await SessionModel.previewSignedIn() }) { session in
        MembersView()
            .environment(session)
    }
}
#endif
