import Foundation

enum BrokerError: Error, Equatable, Sendable {
    /// Non-2xx HTTP response. `message` is the broker's verbatim `{"error":...}` text when present.
    case http(status: Int, message: String?)
    /// Could not reach the broker (connection refused, timeout, etc.).
    case transport(String)
    /// Response body could not be decoded into the expected type.
    case decoding(String)

    /// Build from an HTTP status and raw body, decoding the `{"error": "..."}` envelope if present.
    static func from(status: Int, data: Data) -> BrokerError {
        struct Envelope: Decodable { let error: String }
        let message = try? JSONDecoder().decode(Envelope.self, from: data)
        return .http(status: status, message: message?.error)
    }

    /// User-facing string. Broker messages are already user-facing and shown verbatim;
    /// a few status codes get an extra hint.
    var userMessage: String {
        switch self {
        case .http(let status, let message):
            switch status {
            case 401:
                return "Token missing or invalid — check Settings."
            case 409:
                return message ?? "That instance already has an operation in progress."
            default:
                if let message { return message }
                return "Broker returned HTTP \(status)."
            }
        case .transport(let detail):
            return "Can't reach d2-broker. \(detail)"
        case .decoding(let detail):
            return "Unexpected response from d2-broker. \(detail)"
        }
    }
}
