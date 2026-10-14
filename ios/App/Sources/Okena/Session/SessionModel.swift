import OkenaCore
import SwiftUI

/// The app's session: which box, which person, and the API bound to both.
/// The imperative shell only assigns and calls; every decision is in Core
/// or in a pure helper.
@MainActor
@Observable
final class SessionModel {
    enum State: Equatable {
        case checking        // restoring from storage
        case needsInstance   // no host yet
        case needsLogin      // host, no session
        case ready(Me)       // signed in
    }

    private(set) var state: State = .checking
    private(set) var host: InstanceAddress?
    private(set) var instance: Instance?
    private(set) var api: TainaAPI

    /// A sentence for the screen a forced sign out lands on (a 401 or a
    /// deactivated account), shown by the login screen and cleared at the
    /// next connect or login.
    private(set) var notice: String?

    /// The shared thumbnail cache, keyed by rkey and size.
    let thumbnails: ThumbnailStore

    private let hostStore: HostStore
    private let store: SessionStore
    private let transport: Transport

    init(
        host: HostStore = UserDefaultsHostStore(),
        storage: SessionStorage = KeychainSessionStorage(service: "io.taina.app"),
        transport: Transport = URLSessionTransport()
    ) {
        self.hostStore = host
        self.transport = transport
        let store = SessionStore(storage: storage)
        self.store = store
        let api = LiveTainaAPI(transport: transport, host: host, session: store)
        self.api = api
        thumbnails = ThumbnailStore(api: api)
    }

    /// The preview seam: a model already talking to a given API (the fake),
    /// so a screen renders without a box.
    init(api: TainaAPI, host: InstanceAddress?) {
        self.api = api
        hostStore = InMemoryHostStore(host)
        transport = URLSessionTransport()
        store = SessionStore(storage: InMemorySessionStorage())
        thumbnails = ThumbnailStore(api: api)
    }

    /// Restores the saved session, if any, and decides the first screen. A
    /// session that cannot be read counts as absent: the person signs in
    /// again.
    func restore() async {
        host = await hostStore.address()
        switch await store.restore() {
        case .success(.some(let session)):
            state = .ready(session.identity)
        case .success(nil), .failure:
            state = host == nil ? .needsInstance : .needsLogin
        }
    }

    /// Validates what was typed, asks the box, and keeps the address when
    /// the community answers. A box that answers but has no community yet
    /// is its own outcome: the address is not saved, and Setup explains it.
    func connect(_ input: String) async -> TainaResult<Instance> {
        notice = nil
        instance = nil
        switch InstanceAddress.parse(input: input) {
        case .failure(let error):
            return .failure(error)
        case .success(let address):
            // The probe talks to the typed address without saving it: only
            // a bootstrapped community earns a place in the store.
            let probe = LiveTainaAPI(transport: transport, host: InMemoryHostStore(address), session: store)
            let result = await probe.instance()
            switch result {
            case .success(let found):
                instance = found
                guard found.bootstrapped else {
                    return .success(found)
                }
                host = address
                _ = await hostStore.save(address)
                state = .needsLogin
                return .success(found)
            case .failure:
                return result
            }
        }
    }

    /// Creates the session, keeps it, and confirms with the box before
    /// moving on. A failure of the confirmation stays on the login screen;
    /// the stored session is picked up at the next launch.
    func login(username: String, password: String, deviceName: String) async -> TainaResult<Me> {
        notice = nil
        let created = await api.createSession(username: username, password: password, deviceName: deviceName)
        let session: Session
        switch created {
        case .success(let value):
            session = value
        case .failure(let error):
            return .failure(error)
        }
        switch await store.signIn(session) {
        case .success:
            break
        case .failure(let error):
            return .failure(error)
        }
        let confirmed = await api.me()
        switch confirmed {
        case .success(let me):
            state = .ready(me)
            return .success(me)
        case .failure(let error):
            return .failure(error)
        }
    }

    /// Revokes on the box, then leaves locally whatever the answer: leaving
    /// is local, and a stored token the server has already forgotten is
    /// worse than either.
    func signOut() async {
        _ = await api.revokeSession()
        await leaveLocally()
    }

    /// Screens any authenticated result: a 401 or a deactivated account
    /// signs the app out, leaving a sentence for the login screen.
    func screen<Value>(_ outcome: TainaResult<Value>) async -> TainaResult<Value> {
        guard case .failure(.api(let failure)) = outcome else {
            return outcome
        }
        if failure.isDeactivated {
            notice = "Esta conta foi desativada. Fale com o zelador ou a zeladora da comunidade."
            await leaveLocally()
        } else if failure.isUnauthorized {
            notice = "Sua entrada expirou. Entre de novo para continuar."
            await leaveLocally()
        }
        return outcome
    }

    /// Asks the saved box which community it serves, changing nothing: the
    /// login and account screens show the name and the version.
    func probe() async {
        guard host != nil, instance == nil else { return }
        if case .success(let found) = await api.instance(), found.bootstrapped {
            instance = found
        }
    }

    /// Points the app at an address without probing: the preview and UI
    /// test seam. The running app always arrives through `connect`.
    func useInstance(_ address: InstanceAddress) {
        host = address
        Task { _ = await hostStore.save(address) }
        state = .needsLogin
    }

    /// The composition root hands out bound models.
    func makeFilesModel(folderRkey: String?) -> FilesModel {
        FilesModel(api: api, session: self, folderRkey: folderRkey)
    }

    private func leaveLocally() async {
        _ = await store.signOut()
        await thumbnails.clear()
        instance = nil
        state = .needsLogin
    }
}

#if DEBUG
extension SessionModel {
    /// The preview seams: models already in the state the screen shows,
    /// over the fake: no box, no network. The running app never sees these
    /// paths: it arrives through `restore` and `connect`.

    /// The address the previews show: the fake's own community.
    private static var previewAddress: InstanceAddress? {
        if case .success(let address) = InstanceAddress.parse(input: "taina.sapukai.ts.net") {
            return address
        }
        return nil
    }

    private static func previewModel(state: State, host: InstanceAddress?, api: TainaAPI = FakeTainaAPI()) -> SessionModel {
        let model = SessionModel(api: api, host: host)
        model.state = state
        return model
    }

    /// A signed-in model over the given fake: the store holds the session,
    /// so leaving and the forced sign out behave like the real thing.
    private static func signedIn(_ api: FakeTainaAPI) async -> SessionModel {
        let model = SessionModel(api: api, host: previewAddress)
        guard case .success(let session) = await api.createSession(username: "mariinha", password: "segredo", deviceName: "Aparelho de teste") else {
            return previewModel(state: .needsLogin, host: previewAddress, api: api)
        }
        _ = await model.store.signIn(session)
        model.state = .ready(session.identity)
        return model
    }

    /// Setup: nothing typed, nothing saved.
    static func previewSetup() -> SessionModel {
        previewModel(state: .needsInstance, host: nil)
    }

    /// Login: the community answers, nobody is signed in.
    static func previewLogin() async -> SessionModel {
        let api = FakeTainaAPI()
        let model = previewModel(state: .needsLogin, host: previewAddress, api: api)
        if case .success(let found) = await api.instance() {
            model.instance = found
        }
        return model
    }

    /// Login with a field error: the fake's own envelope for an empty
    /// username, so the preview shows the real shape of `details`. A nil
    /// failure is the empty login, and only happens if the fake ever
    /// fails, which it cannot.
    static func previewLoginFieldError() async -> (model: SessionModel, failure: TainaError?) {
        let api = FakeTainaAPI()
        let model = previewModel(state: .needsLogin, host: previewAddress, api: api)
        if case .success(let found) = await api.instance() {
            model.instance = found
        }
        if case .failure(let error) = await api.createSession(username: "", password: "", deviceName: "Aparelho de teste") {
            return (model, error)
        }
        return (model, nil)
    }

    /// Signed in: the fake answered a login and the store holds the
    /// session, so leaving and the forced sign out behave like the real
    /// thing.
    static func previewSignedIn() async -> SessionModel {
        await signedIn(FakeTainaAPI())
    }

    /// The empty-folder preview: a folder the fake just created, still with
    /// nothing inside. The fallback is a seeded folder, which would show
    /// the full list instead, and only happens if the fake ever fails.
    static func previewEmptyFolder() async -> (model: SessionModel, folder: Folder?) {
        let api = FakeTainaAPI()
        let model = await signedIn(api)
        if case .success(let created) = await api.createFolder(name: "Pasta da vizinhanca", parentRkey: nil) {
            return (model, created)
        }
        if case .success(let folders) = await api.listFolders() {
            return (model, folders.first)
        }
        return (model, nil)
    }

    /// The file-detail preview: a seeded file of the fake's. The fallback
    /// shows the root list, and only happens if the fake ever fails.
    static func previewFile() async -> (model: SessionModel, file: File?) {
        let api = FakeTainaAPI()
        let model = await signedIn(api)
        if case .success(let contents) = await api.folderContents(folderRkey: nil, limit: nil, cursor: nil, sort: nil) {
            return (model, contents.items.first)
        }
        return (model, nil)
    }
}
#endif
