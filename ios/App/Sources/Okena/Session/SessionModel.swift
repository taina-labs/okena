import Foundation
import OkenaCore
import SwiftUI
import UIKit

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
        case pendingAuth(PendingAuth)  // deep link open, deciding
    }

    /// A deep link mid-flight: the token of an invite or a reset, with the
    /// screens of Features/Auth on top.
    struct PendingAuth: Equatable {
        enum Kind: Equatable {
            case invite
            case reset
        }

        let kind: Kind
        let token: String
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

    /// The scene phase, seen from the model: activation starts a restrained
    /// poll, the background stops it. No view feeds it. The tokens are
    /// written on the main actor only; `deinit` reads them for cleanup,
    /// when the instance is already exclusively owned, so they sit outside
    /// the actor's checking and out of the observable storage.
    @ObservationIgnored nonisolated(unsafe) private var activeObservation: Any?
    @ObservationIgnored nonisolated(unsafe) private var resignObservation: Any?
    @ObservationIgnored nonisolated(unsafe) private var poll: Task<Void, Never>?

    private static let pollInterval: Duration = .seconds(30)

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
    /// again. On a cold start the deep link can arrive while the restore is
    /// still reading storage, and the link wins: it already decided the
    /// screen, so the restore writes only while nothing else has.
    func restore() async {
        await observeScene()
#if DEBUG
        if await autoConfigure() { return }
#endif
        host = await hostStore.address()
        switch await store.restore() {
        case .success(.some(let session)):
            decide(.ready(session.identity))
        case .success(nil), .failure:
            decide(host == nil ? .needsInstance : .needsLogin)
        }
    }

    /// Writes the state only when the screen is still undecided.
    private func decide(_ target: State) {
        if case .checking = state {
            state = target
        }
    }

#if DEBUG
    /// The script/preview seam for the deep link: `TAINA_DEEPLINK` feeds a URL
    /// on launch, the same way `TAINA_HOST` drives the setup flow, so a
    /// screenshot or a UI test opens an invite without the system's
    /// "Open in Taina?" prompt. The running app arrives through `onOpenURL`.
    func applyLaunchDeepLink() async {
        guard let raw = ProcessInfo.processInfo.environment["TAINA_DEEPLINK"],
              let url = URL(string: raw) else { return }
        await handleDeepLink(url)
    }
#endif

    /// Validates what was typed, asks the box, and keeps the address when
    /// the community answers. A bare host tries https first and then http,
    /// because the pilot box answers plain http; an explicit scheme is
    /// tried as typed. A box that answers but has no community yet is its
    /// own outcome: the address is not saved, and Setup explains it.
    func connect(_ input: String) async -> TainaResult<Instance> {
        notice = nil
        instance = nil
        switch InstanceAddress.candidates(input: input) {
        case .failure(let error):
            return .failure(error)
        case .success(let candidates):
            return await connect(candidates)
        }
    }

    /// Tries the candidates in order and keeps the first address the box
    /// answers; when none does, the primary's failure is the answer the
    /// screen shows.
    private func connect(_ candidates: InstanceAddress.Candidates) async -> TainaResult<Instance> {
        let first = await probeInstance(at: candidates.primary)
        if Self.unreachable(first), let fallback = candidates.fallback {
            let second = await probeInstance(at: fallback)
            if Self.unreachable(second) {
                return first
            }
            return await settleConnect(second, at: fallback)
        }
        return await settleConnect(first, at: candidates.primary)
    }

    /// Nothing answered: the transport never reached a box. The one
    /// failure where the person can act, so the screens say which three
    /// things to check instead of the generic sentence.
    private static func unreachable(_ result: TainaResult<Instance>) -> Bool {
        guard case .failure(.network) = result else { return false }
        return true
    }

    private func probeInstance(at address: InstanceAddress) async -> TainaResult<Instance> {
        let probe = LiveTainaAPI(transport: transport, host: InMemoryHostStore(address), session: store)
        return await probe.instance()
    }

    /// A box that answered earns the address: kept, saved, and the app
    /// moves on to the login.
    private func settleConnect(_ result: TainaResult<Instance>, at address: InstanceAddress) async -> TainaResult<Instance> {
        guard case .success(let found) = result else { return result }
        instance = found
        guard found.bootstrapped else {
            return .success(found)
        }
        host = address
        _ = await hostStore.save(address)
        state = .needsLogin
        return .success(found)
    }

    /// Creates the session, keeps it, and confirms with the box before
    /// moving on. A failure of the confirmation stays on the login screen;
    /// the stored session is picked up at the next launch.
    func login(username: String, password: String, deviceName: String) async -> TainaResult<Me> {
        notice = nil
        return await settle(await api.createSession(username: username, password: password, deviceName: deviceName))
    }

    /// Accepts the invite with what the person typed. On success the
    /// session lands in the store exactly like a login, and the shell
    /// takes over.
    func acceptInvite(token: String, username: String, password: String, displayName: String?, deviceName: String) async -> TainaResult<Me> {
        await settle(await api.acceptInvite(token: token, username: username, password: password, displayName: displayName, deviceName: deviceName))
    }

    /// Defines the new password of the reset link and signs the person in,
    /// the same way a login lands.
    func resetPassword(token: String, password: String, deviceName: String) async -> TainaResult<Me> {
        await settle(await api.resetPassword(token: token, password: password, deviceName: deviceName))
    }

    /// The self-service password change, while signed in: the box keeps
    /// this aparelho's token and revokes the others. The client returns the
    /// app's value, so there is nothing to convert here.
    func updatePassword(current: String, new: String) async -> TainaResult<Void> {
        await api.updatePassword(current: current, new: new)
    }

    /// The tail every sign in shares, whatever produced the session: store
    /// it, confirm with the box, and become ready. A failure of the
    /// confirmation stays on the screen; the stored session is picked up at
    /// the next launch.
    private func settle(_ created: TainaResult<Session>) async -> TainaResult<Me> {
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

    /// The light read the deep link screens open with: does the token still
    /// count? The real validation stays on the submit.
    func checkToken(_ pending: PendingAuth) async -> TainaResult<Bool> {
        switch pending.kind {
        case .invite:
            return await api.inviteStatus(token: pending.token).map(\.valid)
        case .reset:
            return await api.resetStatus(token: pending.token).map(\.valid)
        }
    }

    /// The box's deep link, opened natively: `taina://convite/<token>` or
    /// `taina://redefinir/<token>`, with the box address in the `host`
    /// query param. The link speaks for its own community, so its address
    /// replaces the saved one; without it, the saved box is the one. The
    /// probe is for the community name only: a box that stays silent does
    /// not block the token, whose check happens on the screen. A malformed
    /// link changes nothing.
    func handleDeepLink(_ url: URL) async {
        await open(DeepLink.parse(url))
    }

    /// The invite or reset link pasted as text, resolved through the same
    /// path a tapped link takes. Returns the sentence for what blocked
    /// it, or nil when the deep-link screen took over: the two ways a
    /// paste cannot open are a link that is not ours, and a link that
    /// says nothing about which box while none is saved yet.
    func openPastedInvite(_ text: String) async -> String? {
        guard let link = DeepLink.parse(pasted: text) else {
            return "Este link não pôde ser lido. Confira se copiou o link inteiro, do começo ao fim."
        }
        if link.box == nil, await hostStore.address() == nil {
            return "O link não diz qual é a comunidade e nenhuma foi conectada ainda. Peça o link completo a quem convidou você."
        }
        await open(link)
        return nil
    }

    /// The tail of every arrival, tapped or pasted.
    private func open(_ link: DeepLink?) async {
        guard let link else { return }
        let box: InstanceAddress
        if let typed = link.box {
            guard case .success(let parsed) = InstanceAddress.parse(input: typed) else { return }
            box = parsed
        } else if let saved = await hostStore.address() {
            box = saved
        } else {
            return
        }

        host = box
        _ = await hostStore.save(box)
        instance = nil
        if case .success(let found) = await api.instance(), found.bootstrapped {
            instance = found
        }
        state = .pendingAuth(PendingAuth(kind: link.kind == .invite ? .invite : .reset, token: link.token))
    }

    /// Leaves the deep link screen for the normal flow: a session the
    /// person already held is still theirs, so it is the way back; without
    /// one, the saved box leads to the login, and with no box, the setup.
    func leavePendingAuth() async {
        if let current = await store.current() {
            state = .ready(current.identity)
            return
        }
        host = await hostStore.address()
        state = host == nil ? .needsInstance : .needsLogin
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

    /// The scene is active again (or the poll ticked): the box may have
    /// moved on, and the token may have been revoked elsewhere. A fresh
    /// `me` keeps the identity and its quota honest and re-saves it; a
    /// revoked or deactivated session leaves through `screen`, with its
    /// sentence on the login. A box away for a moment changes nothing,
    /// and the deep-link screens decide on their own.
    func refresh() async {
        switch state {
        case .ready:
            let result = await screen(await api.me())
            if case .success(let me) = result {
                state = .ready(me)
                _ = await store.refreshIdentity(me)
            }
        case .needsLogin, .needsInstance:
            await probe()
        case .checking, .pendingAuth:
            break
        }
    }

    /// The scene phase, seen from the model: the app observes its own
    /// activation through the system notifications, so no view needs to
    /// feed it. The poll exists only while the scene is active, and the
    /// launch activation can land before this registration, so an already
    /// active scene starts it now.
    private func observeScene() async {
        guard activeObservation == nil else { return }
        let center = NotificationCenter.default
        activeObservation = center.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in await self?.sceneActivated() }
        }
        resignObservation = center.addObserver(
            forName: UIApplication.willResignActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.sceneDeactivated() }
        }
        if UIApplication.shared.applicationState == .active {
            await sceneActivated()
        }
    }

    private func sceneActivated() async {
        guard poll == nil else { return }
        await refresh()
        poll = Task { [weak self] in
            while !Task.isCancelled {
                do {
                    try await Task.sleep(for: Self.pollInterval)
                } catch {
                    return  // the scene went to the background: the poll stops
                }
                await self?.refresh()
            }
        }
    }

    private func sceneDeactivated() {
        poll?.cancel()
        poll = nil
    }

    deinit {
        if let activeObservation { NotificationCenter.default.removeObserver(activeObservation) }
        if let resignObservation { NotificationCenter.default.removeObserver(resignObservation) }
        poll?.cancel()
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

#if DEBUG
    /// Points the app at a box without typing, and optionally signs in, so
    /// the flow can be driven from a script or a UI test. The simulator
    /// passes these through `SIMCTL_CHILD_` variables. Everything a person's
    /// run does happens here too, including keeping the address; signing in
    /// writes the session to the Keychain, which is what signing in means.
    private func autoConfigure() async -> Bool {
        let environment = ProcessInfo.processInfo.environment
        guard let typed = environment["TAINA_HOST"] else {
            return false
        }

        // The same path a person takes: parse, probe the box, keep the
        // address. Only the keystrokes are missing.
        _ = await connect(typed)

        if let username = environment["TAINA_USERNAME"],
           let password = environment["TAINA_PASSWORD"] {
            if case .failure(let error) = await login(username: username, password: password, deviceName: "Simulador") {
                // Swallowing this costs an afternoon; the screen says it.
                notice = error.errorDescription
            }
        }
        return true
    }
#endif

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

    /// A deep link mid-flight over the fake: the model in pendingAuth and
    /// the community probed, so the screen renders its form. `expired`
    /// hands the fake's dead token, and the same seam previews the dead
    /// end.
    static func previewPendingInvite(expired: Bool = false) async -> (model: SessionModel, pending: PendingAuth) {
        await pendingAuth(.invite, expired: expired)
    }

    /// The same seam, for the reset link.
    static func previewPendingReset(expired: Bool = false) async -> (model: SessionModel, pending: PendingAuth) {
        await pendingAuth(.reset, expired: expired)
    }

    private static func pendingAuth(_ kind: PendingAuth.Kind, expired: Bool) async -> (model: SessionModel, pending: PendingAuth) {
        let api = FakeTainaAPI()
        let model = previewModel(state: .needsLogin, host: previewAddress, api: api)
        if case .success(let found) = await api.instance() {
            model.instance = found
        }
        let pending = PendingAuth(kind: kind, token: expired ? "expirado" : "tk9x2m5qp7w4v8")
        model.state = .pendingAuth(pending)
        return (model, pending)
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
