import Foundation
import OkenaCore

/// Walks the fatia minima of the API against a live box, through the same
/// `OkenaCore` client the app uses. That is the point: when a screen
/// misbehaves, this says which layer is wrong, the box or the client.
///
/// Reads by default. `--write` also creates a folder and uploads a file,
/// and prints exactly what it left behind. The device token is never printed.
///
///     swift run okena-smoke http://taina.yby --user ana --password segredo --write

@main
struct Smoke {
    static func main() async {
        let arguments = Array(CommandLine.arguments.dropFirst())
        guard let typed = arguments.first(where: { !$0.hasPrefix("--") }) else {
            print(usage)
            exit(2)
        }

        let parsed = InstanceAddress.parse(input: typed)
        guard case .success(let address) = parsed else {
            print("endereco: recusado, veja o formato em taina.minhacasa.ts.net")
            exit(1)
        }

        let host = InMemoryHostStore(address)
        let store = SessionStore(storage: InMemorySessionStorage())
        let api = LiveTainaAPI(host: host, session: store)

        print("caixa: \(address.display)\(address.isCleartext ? " (sem criptografia)" : "")")

        let instance = await api.instance()
        print(line("instance", instance))
        guard case .success(let found) = instance, found.bootstrapped else {
            print("a comunidade ainda nao existe nessa caixa")
            exit(1)
        }

        if let user = value(of: "--user", in: arguments), let password = value(of: "--password", in: arguments) {
            switch await api.createSession(username: user, password: password, deviceName: "okena-smoke") {
            case .failure(let error):
                print("session: falhou (\(error.errorDescription ?? "?"))")
                exit(1)
            case .success(let session):
                print("session: aparelho \"\(session.device.name)\" id=\(session.device.publicId), token criado e nao impresso")
                _ = await store.signIn(session)
            }
        }

        print(line("me", await api.me()))
        print(line("folders", await api.listFolders()))
        print(line("contents (raiz)", await api.folderContents(folderRkey: nil, limit: nil, cursor: nil, sort: nil)))

        if arguments.contains("--write") {
            await write(api)
        }

        print("fim")
    }

    /// Creates a folder, uploads a small text file, reads it back and asks
    /// for its thumbnail, which a text file does not have.
    private static func write(_ api: LiveTainaAPI) async {
        guard case .success(let folder) = await api.createFolder(name: "pasta-do-smoke", parentRkey: nil) else {
            print("write: criar pasta falhou")
            return
        }
        print("write: pasta criada \(folder.rkey) \"\(folder.name)\" zona=\(folder.zona.rawValue)")

        let body = """
        Arquivo criado pelo okena-smoke para provar upload, download e listagem.
        Se ele ainda esta na comunidade depois do teste, pode apagar.

        """
        let source = FileManager.default.temporaryDirectory.appending(path: "teste-do-smoke.txt")
        try? Data(body.utf8).write(to: source)

        let uploaded = await api.upload(fileAt: source, name: "teste-do-smoke.txt", mime: "text/plain", folderRkey: folder.rkey)
        guard case .success(let file) = uploaded else {
            print(line("write: upload", uploaded))
            return
        }
        print("write: arquivo \(file.rkey) \(file.name) \(file.size) bytes sha256=\(file.sha256.prefix(16))...")

        print(line("write: a pasta agora", await api.folderContents(folderRkey: folder.rkey, limit: nil, cursor: nil, sort: nil)))

        switch await api.download(rkey: file.rkey) {
        case .failure(let error):
            print("write: download falhou (\(error.errorDescription ?? "?"))")
        case .success(let url):
            let bytes = (try? Data(contentsOf: url)) ?? Data()
            print("write: download \(bytes.count) bytes, nome \"\(url.lastPathComponent)\", igual ao enviado=\(bytes == Data(body.utf8))")
        }

        switch await api.thumbnail(rkey: file.rkey, size: .sm) {
        case .failure(.api(let error)):
            print("write: miniatura recusada como esperado para um texto, code=\(error.code) status=\(error.status)")
        case .failure(let error):
            print("write: miniatura falhou de outro jeito (\(error.errorDescription ?? "?"))")
        case .success(let data):
            print("write: miniatura \(data.count) bytes (inesperado para um texto)")
        }
    }

    private static func line<Value>(_ label: String, _ result: TainaResult<Value>) -> String {
        switch result {
        case .failure(let error):
            "\(label): falhou (\(error.errorDescription ?? "?"))"
        case .success(let value):
            "\(label): \(describe(value))"
        }
    }

    private static func describe(_ value: Any) -> String {
        switch value {
        case let me as Me:
            "\(me.ava.label) @\(me.ava.username) papel=\(me.ava.papel.rawValue) comunidade=\(me.tekoa.name)"
        case let folders as [Folder]:
            "\(folders.count): " + folders.map { "\($0.name)[\($0.zona.rawValue)]" }.joined(separator: ", ")
        case let contents as FolderContents:
            "\(contents.folders.count) pasta(s), \(contents.items.count) arquivo(s), next_cursor=\(contents.nextCursor ?? "-")"
        case let instance as Instance:
            "bootstrapped=\(instance.bootstrapped) comunidade=\(instance.tekoa?.name ?? "-") versao=\(instance.version ?? "-")"
        default:
            String(describing: value)
        }
    }

    private static func value(of flag: String, in arguments: [String]) -> String? {
        guard let index = arguments.firstIndex(of: flag), arguments.indices.contains(index + 1) else {
            return nil
        }
        return arguments[index + 1]
    }

    private static let usage = """
    uso: okena-smoke <endereco> [--user <usuario>] [--password <senha>] [--write]

      <endereco>            por exemplo http://taina.yby
      --user, --password    entra por token de dispositivo antes de listar
      --write               cria a pasta pasta-do-smoke e sobe teste-do-smoke.txt
    """
}
