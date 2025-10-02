import Foundation

struct OpenAIResponsesEnvelope: Decodable {
    let output: [Output]?
    let response: [Output]?
    let usage: Usage?
    let status: String?
    let incompleteDetails: IncompleteDetails?

    var outputs: [Output] {
        if let response { return response }
        if let output { return output }
        return []
    }

    var isIncompleteDueToMaxTokens: Bool {
        status == "incomplete" && incompleteDetails?.reason == "max_output_tokens"
    }

    struct Usage: Decodable {
        let totalTokens: Int?
        let promptTokens: Int?
        let completionTokens: Int?

        enum CodingKeys: String, CodingKey {
            case totalTokens = "total_tokens"
            case promptTokens = "prompt_tokens"
            case completionTokens = "completion_tokens"
        }
    }

    struct Output: Decodable {
        let id: String?
        let type: String?
        let status: String?
        let role: String?
        let content: [Content]

        enum CodingKeys: String, CodingKey {
            case id
            case type
            case status
            case role
            case content
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            id = try container.decodeIfPresent(String.self, forKey: .id)
            type = try container.decodeIfPresent(String.self, forKey: .type)
            status = try container.decodeIfPresent(String.self, forKey: .status)
            role = try container.decodeIfPresent(String.self, forKey: .role)
            content = try container.decodeIfPresent([Content].self, forKey: .content) ?? []
        }
    }

    struct Content: Decodable {
        let type: ContentType
        let text: String?
        let jsonObject: Any?
        let refusal: Refusal?
        let annotations: [Annotation]?

        enum CodingKeys: String, CodingKey {
            case type
            case text
            case json
            case refusal
            case annotations
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let rawType = try container.decode(String.self, forKey: .type)
            type = ContentType(rawValue: rawType)
            text = try container.decodeIfPresent(String.self, forKey: .text)
            if container.contains(.json) {
                jsonObject = try container.decode(AnyDecodable.self, forKey: .json).value
            } else {
                jsonObject = nil
            }
            refusal = try container.decodeIfPresent(Refusal.self, forKey: .refusal)
            annotations = try container.decodeIfPresent([Annotation].self, forKey: .annotations)
        }

        func jsonData() -> Data? {
            guard let jsonObject else { return nil }
            guard JSONSerialization.isValidJSONObject(jsonObject) else { return nil }
            return try? JSONSerialization.data(withJSONObject: jsonObject)
        }
    }

    struct Refusal: Decodable {
        let code: String?
        let reason: String?
    }

    struct IncompleteDetails: Decodable {
        let reason: String?
    }

    struct Annotation: Decodable {
        let type: String
        let text: String?
        let explanation: String?
    }

    enum ContentType: Equatable {
        case outputJSON
        case outputText
        case refusal
        case reasoning
        case annotations
        case inputText
        case other(String)

        init(rawValue: String) {
            switch rawValue {
            case "output_json": self = .outputJSON
            case "output_text": self = .outputText
            case "refusal": self = .refusal
            case "reasoning": self = .reasoning
            case "annotations": self = .annotations
            case "input_text": self = .inputText
            default: self = .other(rawValue)
            }
        }

        var identifier: String {
            switch self {
            case .outputJSON: return "output_json"
            case .outputText: return "output_text"
            case .refusal: return "refusal"
            case .reasoning: return "reasoning"
            case .annotations: return "annotations"
            case .inputText: return "input_text"
            case .other(let raw): return raw
            }
        }
    }
}

private struct AnyDecodable: Decodable {
    let value: Any

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if container.decodeNil() {
            value = NSNull()
        } else if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let string = try? container.decode(String.self) {
            value = string
        } else if let array = try? container.decode([AnyDecodable].self) {
            value = array.map { $0.value }
        } else if let dictionary = try? container.decode([String: AnyDecodable].self) {
            value = dictionary.mapValues { $0.value }
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unsupported JSON value")
        }
    }
}
