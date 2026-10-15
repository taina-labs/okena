import OkenaCore
import SwiftUI

/// The community's people, as the box lists them: zeladoras first. Read
/// only, for every morador.
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

/// The list itself: loading, empty and failure each have their place, and
/// the pull to refresh reloads through the model.
struct MemberList: View {
    let model: MembersModel

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
    }

    private var list: some View {
        ScrollView {
            LazyVStack(spacing: Theme.Space.space2) {
                Text(MembersModel.countLine(model.members.count))
                    .typeStyle(Theme.Text.overline)
                    .foregroundStyle(Theme.Palette.textMuted)
                    .frame(maxWidth: .infinity, alignment: .leading)
                ForEach(model.members, id: \.publicId) { member in
                    RowCard {
                        MemberRow(member: member, mePublicId: model.mePublicId)
                    }
                }
            }
            .padding(Theme.Space.space4)
        }
    }
}

/// One person: the mark, the name, the role, and the state when there is
/// one (deactivated, or the person holding the phone).
struct MemberRow: View {
    let member: Ava
    var mePublicId: String?

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
        }
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

#if DEBUG
#Preview("Moradores") {
    PreviewHost(make: { await SessionModel.previewSignedIn() }) { session in
        MembersView()
            .environment(session)
    }
}
#endif
