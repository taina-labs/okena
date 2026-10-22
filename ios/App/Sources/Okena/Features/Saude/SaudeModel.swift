import OkenaCore
import SwiftUI

/// The saúde panel's state: one load of `GET /saude`, the rows built by
/// pure functions. Facts of the present, in plain words, for the whole
/// community: no backup trigger here, care stays with whoever keeps the box.
@MainActor
@Observable
final class SaudeModel {
    /// One row of the panel: an icon, a label, the facts as lines, and the
    /// warning when the fact needs one. Icon and phrase together, never a
    /// color alone.
    struct Row: Equatable, Identifiable {
        var icon: String
        var label: String
        var lines: [String]
        var warning: String?

        var id: String { icon }

        init(icon: String, label: String, lines: [String], warning: String? = nil) {
            self.icon = icon
            self.label = label
            self.lines = lines
            self.warning = warning
        }
    }

    /// The share of the quota where "o espaço está acabando" starts, the
    /// web's own threshold.
    private static let diskWarningShare = 0.9

    private(set) var saude: Saude?
    private(set) var loading = false
    private(set) var error: TainaError?
    /// Whether the box is taking the backup request right now.
    private(set) var triggering = false

    private let api: TainaAPI
    private let session: SessionModel

    init(api: TainaAPI, session: SessionModel) {
        self.api = api
        self.session = session
    }

    /// The acts belong to whoever cares for the box; the server enforces
    /// it again anyway.
    var isZelador: Bool {
        if case .ready(let me) = session.state {
            return me.ava.papel == .zelador
        }
        return false
    }

    func load() async {
        loading = true
        let result = await api.saude()
        switch await session.screen(result) {
        case .success(let value):
            saude = value
            error = nil
        case .failure(let failure):
            error = failure
        }
        loading = false
    }

    /// Asks the box to back itself up now: the answer is the queue, not
    /// the backup, so the row still reads the last one that finished.
    func backupNow() async -> TainaResult<Void> {
        triggering = true
        defer { triggering = false }
        return await session.screen(await api.triggerBackup())
    }

    // MARK: pure transitions

    /// The panel's rows, in the order of the web's: disco, backup, and the
    /// queued work, which disappears when there is none.
    static func rows(from saude: Saude) -> [Row] {
        [diskRow(saude.storage), backupRow(saude.backup), jobsRow(saude.jobs)].compactMap { $0 }
    }

    static func diskRow(_ stats: StorageStats) -> Row {
        var lines: [String]
        if let quota = stats.quotaBytes {
            let free = max(quota - stats.usedBytes, 0)
            lines = ["\(Format.bytes(stats.usedBytes)) usados de \(Format.bytes(quota)). \(Format.bytes(free)) livres."]
        } else {
            lines = ["\(Format.bytes(stats.usedBytes)) usados. Sem limite definido."]
        }
        lines.append(contentsOf: trashLines(stats.trash))
        return Row(
            icon: "externaldrive",
            label: "Disco",
            lines: lines,
            warning: isAlmostFull(stats) ? "O espaço está acabando. Quem cuida da máquina pode aumentar o limite." : nil
        )
    }

    /// The trash still counts against the quota until the purge: said in
    /// aggregate, no names. An empty trash is no fact, no line.
    static func trashLines(_ trash: StorageStats.Trash) -> [String] {
        guard trash.count > 0 else { return [] }
        let files = trash.count == 1 ? "1 arquivo" : "\(trash.count) arquivos"
        return ["\(Format.bytes(trash.bytes)) na lixeira esperando a limpeza (\(files))."]
    }

    static func isAlmostFull(_ stats: StorageStats) -> Bool {
        guard let quota = stats.quotaBytes, quota > 0 else { return false }
        return Double(stats.usedBytes) / Double(quota) >= diskWarningShare
    }

    static func backupRow(_ backup: Saude.Backup) -> Row {
        let lines: [String]
        if let at = backup.at, let bytes = backup.bytes {
            lines = ["Terminou bem \(Format.date(at)) (\(Format.bytes(bytes)) guardados)."]
        } else if let at = backup.at {
            lines = ["Terminou bem \(Format.date(at))."]
        } else {
            lines = ["Nunca foi feito um backup.", "Quem cuida da máquina cuida do backup."]
        }
        return Row(icon: "shield", label: Self.backupLabel, lines: lines)
    }

    /// The label of the backup row, the anchor the screen hangs the
    /// zeladora's act on.
    static let backupLabel = "Último backup"

    /// Work waiting or running, one line per queue with work. All quiet,
    /// no row at all: a zero is a number, not a fact.
    static func jobsRow(_ jobs: [String: Int64]) -> Row? {
        let lines = jobLines(jobs)
        guard !lines.isEmpty else { return nil }
        return Row(icon: "clock", label: "Trabalhos da caixa", lines: lines)
    }

    static func jobLines(_ jobs: [String: Int64]) -> [String] {
        jobs
            .filter { $0.value > 0 }
            .sorted { $0.key < $1.key }
            .map { jobLine(queue: $0.key, count: $0.value) }
    }

    /// The queues the box has, in the words the web uses; an unknown queue
    /// keeps its name and is said plainly.
    static func jobLine(queue: String, count: Int64) -> String {
        switch queue {
        case "renditions":
            count == 1 ? "1 miniatura ainda sendo gerada" : "\(count) miniaturas ainda sendo geradas"
        case "trash_purge":
            count == 1 ? "1 limpeza da lixeira em andamento" : "\(count) limpezas da lixeira em andamento"
        case "backups":
            count == 1 ? "1 backup em andamento" : "\(count) backups em andamento"
        default:
            count == 1 ? "1 trabalho na fila \(queue)" : "\(count) trabalhos na fila \(queue)"
        }
    }
}
