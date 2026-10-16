import Foundation

extension JSONDecoder {
    /// Decodes, or reports the shape that did not match. The throw stops
    /// here: above this line, failure is a value.
    func decode<Value: Decodable>(
        _ type: Value.Type,
        from data: Data,
        label: String
    ) -> TainaResult<Value> {
        guard let value = try? decode(Value.self, from: data) else {
            return .failure(.invalidResponse(label))
        }
        return .success(value)
    }
}

/// The one configured JSON pair for the API. The wire is snake_case and the
/// Swift properties read camelCase; the pt-BR single-word keys (zona, papel,
/// tipo) have no underscore and pass through untouched. Dates stay String:
/// the server sends ISO 8601 with an offset, and formatting for people is
/// the app's job.
enum APICoding {
    static var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }

    static var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        return encoder
    }
}
