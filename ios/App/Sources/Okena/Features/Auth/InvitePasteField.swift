import OkenaCore
import SwiftUI

/// The paste field of the invite link, on the two screens where the app
/// can still be pointed at a community. The link arrives as text or as a
/// QR shot, in either of the box's two shapes (contract E), and goes
/// through the same deep-link path a tapped link takes: the link speaks
/// for its own community. What cannot open comes back as a sentence
/// under the field.
struct InvitePasteField: View {
    @Environment(SessionModel.self) private var session

    @State private var link = ""
    @State private var problem: String?

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.space2) {
            Text("Chegou por um convite?")
                .typeStyle(Theme.Text.overline)
                .foregroundStyle(Theme.Palette.textMuted)
            TainaField(
                label: "Cole aqui o link do convite",
                text: $link,
                errorMessages: problem.map { [$0] } ?? [],
                contentType: .URL,
                placeholder: "taina://convite/... ou https://.../convite/...",
                help: "É o link que a comunidade mandou, por mensagem ou no QR code."
            )
            SecondaryButton(title: "Abrir o convite") {
                Task { await open() }
            }
        }
    }

    private func open() async {
        problem = await session.openPastedInvite(link)
    }
}
