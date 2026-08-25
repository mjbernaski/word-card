#if !os(tvOS)
import Foundation
import Security

struct CardProposal: Sendable {
    let text: String
    let notes: String
    let category: CardCategory
    let valence: Int
    let sourceURL: URL
}

enum CardProposalError: LocalizedError {
    case invalidURL
    case insecureURL
    case unsupportedContent
    case emptyPage
    case invalidResponse
    case requestFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Enter a complete webpage URL."
        case .insecureURL:
            return "The source URL must use HTTPS."
        case .unsupportedContent:
            return "That URL did not return a readable webpage."
        case .emptyPage:
            return "No readable text was found on that page."
        case .invalidResponse:
            return "OpenAI returned a response the app could not read."
        case .requestFailed(let message):
            return message
        }
    }
}

struct CardProposalService {
    private static let endpoint = URL(string: "https://api.openai.com/v1/responses")!

    func propose(from sourceURL: URL, apiKey: String) async throws -> CardProposal {
        guard sourceURL.scheme?.lowercased() == "https" else {
            throw CardProposalError.insecureURL
        }

        var pageRequest = URLRequest(url: sourceURL)
        pageRequest.timeoutInterval = 30
        pageRequest.setValue("text/html, text/plain;q=0.9", forHTTPHeaderField: "Accept")
        pageRequest.setValue("WordCard/1.0", forHTTPHeaderField: "User-Agent")

        let (pageData, pageResponse) = try await URLSession.shared.data(for: pageRequest)
        guard let httpResponse = pageResponse as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw CardProposalError.requestFailed("The webpage could not be downloaded.")
        }

        let contentType = httpResponse.value(forHTTPHeaderField: "Content-Type")?.lowercased() ?? ""
        guard contentType.isEmpty || contentType.contains("text/html") || contentType.contains("text/plain") else {
            throw CardProposalError.unsupportedContent
        }

        let pageText = readableText(from: pageData, contentType: contentType)
        guard !pageText.isEmpty else { throw CardProposalError.emptyPage }

        var apiRequest = URLRequest(url: Self.endpoint)
        apiRequest.httpMethod = "POST"
        apiRequest.timeoutInterval = 60
        apiRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        apiRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        apiRequest.httpBody = try JSONSerialization.data(withJSONObject: requestBody(pageText: pageText, sourceURL: sourceURL))

        let (data, response) = try await URLSession.shared.data(for: apiRequest)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw CardProposalError.invalidResponse
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            let apiError = try? JSONDecoder().decode(APIErrorEnvelope.self, from: data)
            throw CardProposalError.requestFailed(apiError?.error.message ?? "OpenAI request failed (HTTP \(httpResponse.statusCode)).")
        }

        let apiResponse = try JSONDecoder().decode(ResponsesEnvelope.self, from: data)
        guard let jsonText = apiResponse.output
            .flatMap({ $0.content ?? [] })
            .first(where: { $0.type == "output_text" })?.text,
              let proposalData = jsonText.data(using: .utf8),
              let generated = try? JSONDecoder().decode(GeneratedProposal.self, from: proposalData) else {
            throw CardProposalError.invalidResponse
        }

        return CardProposal(
            text: String(generated.text.trimmingCharacters(in: .whitespacesAndNewlines).prefix(500)),
            notes: String(generated.notes.trimmingCharacters(in: .whitespacesAndNewlines).prefix(500)),
            category: CardCategory(rawValue: generated.category) ?? .readings,
            valence: max(-5, min(5, generated.valence)),
            sourceURL: sourceURL
        )
    }

    private func requestBody(pageText: String, sourceURL: URL) -> [String: Any] {
        [
            "model": "gpt-5-mini",
            "instructions": "Propose one durable, standalone knowledge card from the supplied webpage. Capture its most useful idea, not a page summary. Do not invent facts. The text must be concise and understandable without visiting the source. Notes may briefly explain context. Choose exactly one category. Valence is an integer from -5 (strongly negative) through 5 (strongly positive).",
            "input": "Source URL: \(sourceURL.absoluteString)\n\nWebpage text:\n\(pageText)",
            "max_output_tokens": 500,
            "text": [
                "format": [
                    "type": "json_schema",
                    "name": "card_proposal",
                    "strict": true,
                    "schema": [
                        "type": "object",
                        "properties": [
                            "text": ["type": "string"],
                            "notes": ["type": "string"],
                            "category": ["type": "string", "enum": ["idea", "readings", "miscellaneous"]],
                            "valence": ["type": "integer", "minimum": -5, "maximum": 5]
                        ],
                        "required": ["text", "notes", "category", "valence"],
                        "additionalProperties": false
                    ]
                ]
            ]
        ]
    }

    private func readableText(from data: Data, contentType: String) -> String {
        let cappedData = data.prefix(2_000_000)
        guard var text = String(data: cappedData, encoding: .utf8) else { return "" }
        if contentType.contains("text/html") || text.localizedCaseInsensitiveContains("<html") {
            text = text.replacingOccurrences(of: "(?is)<(script|style|noscript).*?>.*?</\\1>", with: " ", options: .regularExpression)
            text = text.replacingOccurrences(of: "(?s)<[^>]+>", with: " ", options: .regularExpression)
            let entities = ["&nbsp;": " ", "&amp;": "&", "&lt;": "<", "&gt;": ">", "&quot;": "\"", "&#39;": "'"]
            for (entity, replacement) in entities {
                text = text.replacingOccurrences(of: entity, with: replacement)
            }
        }
        text = text.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return String(text.prefix(50_000))
    }
}

enum OpenAIKeychain {
    private static let service = "mjbernaski.wordcard.openai"
    private static let account = "api-key"

    static func load() -> String {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data,
              let key = String(data: data, encoding: .utf8) else { return "" }
        return key
    }

    static func save(_ key: String) throws {
        let data = Data(key.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        let attributes: [String: Any] = [kSecValueData as String: data]
        let status: OSStatus
        if SecItemCopyMatching(query as CFDictionary, nil) == errSecSuccess {
            status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        } else {
            status = SecItemAdd(query.merging(attributes) { _, new in new } as CFDictionary, nil)
        }
        guard status == errSecSuccess else {
            throw CardProposalError.requestFailed("The API key could not be saved to Keychain.")
        }
    }

    static func delete() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
    }
}

private struct GeneratedProposal: Decodable {
    let text: String
    let notes: String
    let category: String
    let valence: Int
}

private struct ResponsesEnvelope: Decodable {
    let output: [ResponseOutput]
}

private struct ResponseOutput: Decodable {
    let content: [ResponseContent]?
}

private struct ResponseContent: Decodable {
    let type: String
    let text: String?
}

private struct APIErrorEnvelope: Decodable {
    let error: APIErrorBody
}

private struct APIErrorBody: Decodable {
    let message: String
}
#endif
