import Testing

@testable import Okena
@testable import OkenaCore

private let me = "avap2xw5m8q3"
private let joana = "avaq7r2m5xk9p1"

private func folder(
    _ rkey: String,
    name: String,
    parent: String? = nil,
    dono: String? = me
) -> Folder {
    Folder(
        rkey: rkey,
        cid: "bm" + rkey,
        name: name,
        zona: .casa,
        folder: parent,
        dono: dono,
        deletedAt: nil,
        createdAt: "2026-10-14T08:00:00Z",
        updatedAt: "2026-10-14T08:00:00Z"
    )
}

/// The destinations a move offers are the person's own folders: the wire's
/// `dono` filters out everyone else's, and the ones whose owner is gone.
@Test @MainActor func moveOffersTheFoldersTheCallerOwns() {
    let mine = folder("3kaaa1", name: "Minha pasta", dono: me)
    let theirs = folder("3kaaa2", name: "Pasta da Joana", dono: joana)
    let ownerless = folder("3kaaa3", name: "Sem dona", dono: nil)

    let offered = FilesModel.moveDestinations(
        from: "3kaaa9",
        isFolder: false,
        among: [mine, theirs, ownerless],
        ownedBy: me
    )

    #expect(offered.map(\.rkey) == [mine.rkey])
}

/// A folder source is not offered itself, and neither is its subtree,
/// where the move would close a cycle the box refuses.
@Test @MainActor func aFolderSourceIsNotOfferedNorItsDescendants() {
    let source = folder("3ksrc1", name: "Fonte")
    let child = folder("3kchi2", name: "Pasta de dentro", parent: source.rkey)
    let elsewhere = folder("3kels3", name: "Pasta de fora")

    let offered = FilesModel.moveDestinations(
        from: source.rkey,
        isFolder: true,
        among: [source, child, elsewhere],
        ownedBy: me
    )

    #expect(offered.map(\.rkey) == [elsewhere.rkey])
}

/// The cycle check walks every folder's chain of parents, owned or not:
/// a candidate of mine sitting inside a folder of Joana's that sits
/// inside the source is still a cycle, and is not offered.
@Test @MainActor func aCycleThroughAFolderOfAnotherPersonIsStillRefused() {
    let source = folder("3ksrc1", name: "Fonte")
    let bridge = folder("3kbrg2", name: "Ponte da Joana", parent: source.rkey, dono: joana)
    let candidate = folder("3kcnd3", name: "Candidata", parent: bridge.rkey)

    let offered = FilesModel.moveDestinations(
        from: source.rkey,
        isFolder: true,
        among: [source, bridge, candidate],
        ownedBy: me
    )

    #expect(offered.isEmpty)
}
