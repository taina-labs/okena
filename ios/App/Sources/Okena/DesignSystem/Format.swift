import Foundation

/// Pure pt-BR formatting: sizes and dates. Dates parse as ISO 8601 and
/// print with a fixed pt-BR locale, no device-locale surprises.
enum Format {
    /// Bytes for a person: "834 B", "1,2 KB", "2,4 MB", "1,8 GB". Decimal
    /// comma, one decimal above KB, like the web.
    static func bytes(_ count: Int64) -> String {
        let kilo = 1024.0
        let value = Double(count)
        switch value {
        case ..<kilo:
            return "\(count) B"
        case ..<(kilo * kilo):
            return decimal(value / kilo) + " KB"
        case ..<(kilo * kilo * kilo):
            return decimal(value / (kilo * kilo)) + " MB"
        default:
            return decimal(value / (kilo * kilo * kilo)) + " GB"
        }
    }

    /// "10 de mar. de 2026 às 14:00". A date that cannot be parsed comes
    /// back as sent, never empty and never "Invalid Date".
    static func date(_ iso: String) -> String {
        guard let parsed = parse(iso) else {
            return iso
        }
        return parsed.formatted(Date.FormatStyle(date: .abbreviated, time: .shortened, locale: ptBR))
    }

    /// "hoje", "ontem", "3 dias", then a short date. For list rows.
    static func relative(_ iso: String) -> String {
        guard let parsed = parse(iso) else {
            return iso
        }
        let calendar = Calendar.current
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: parsed), to: calendar.startOfDay(for: Date.now)).day ?? 0
        switch days {
        case 0:
            return "hoje"
        case 1:
            return "ontem"
        case 2..<7:
            return "\(days) dias"
        default:
            return parsed.formatted(Date.FormatStyle(date: .numeric, time: .omitted, locale: ptBR))
        }
    }

    private static let ptBR = Locale(identifier: "pt_BR")

    /// The dot of "%.1f" is the comma a Brazilian reads.
    private static func decimal(_ value: Double) -> String {
        String(format: "%.1f", value).replacingOccurrences(of: ".", with: ",")
    }

    // The server sends ISO 8601 with an offset; fractional seconds happen.
    // Formatters live locally, not as globals: they are not Sendable.
    private static func parse(_ iso: String) -> Date? {
        let whole = ISO8601DateFormatter()
        if let date = whole.date(from: iso) {
            return date
        }
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return fractional.date(from: iso)
    }
}
