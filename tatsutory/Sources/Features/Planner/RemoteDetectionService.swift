import Foundation
import UIKit

struct RemoteDetectionItem: Codable {
    let id: String
    let label: String
    let bbox: [Double]
    let confidence: Double
}

struct RemoteDetectionResponse: Codable {
    let items: [RemoteDetectionItem]
}

final class RemoteDetectionService {
    private let apiKey: String
    private let timeout: TimeInterval = 30.0
    private let model = "gpt-5-mini"

    init(apiKey: String) {
        self.apiKey = apiKey
    }

    func detect(from image: UIImage, settings: IntentSettings) async throws -> [DetectedItem] {
        guard let payload = image.resized(maxDimension: 1080).strippedJPEGData(quality: 0.7) else {
            TelemetryTracker.shared.event("detector_remote_status", ["status": "image_encoding_failed"])
            return []
        }
        let base64 = payload.base64EncodedString()
        let request = try buildRequest(base64: base64, settings: settings)
        let (data, response) = try await performRequest(request: request)
        guard let http = response as? HTTPURLResponse else {
            TelemetryTracker.shared.event("detector_remote_status", ["status": "invalid_response"])
            return []
        }
        if http.statusCode == 429 {
            TelemetryTracker.shared.event("detector_remote_status", ["status": "429"])
            throw TatsuToriError.rateLimited(retryAfter: retryAfterInterval(from: http))
        }
        guard (200...299).contains(http.statusCode) else {
            let bodyString = String(data: data, encoding: .utf8) ?? "-"
            TelemetryTracker.shared.event(
                "detector_remote_status",
                ["status": "http_\(http.statusCode)", "body": bodyString]
            )
            let error = NSError(
                domain: "HTTP",
                code: http.statusCode,
                userInfo: [NSLocalizedDescriptionKey: "HTTP \(http.statusCode): \(bodyString)"]
            )
            throw TatsuToriError.networkError(error)
        }

        guard let encoded = try decodeResponse(data) else {
            let bodyString = String(data: data, encoding: .utf8) ?? "-"
            TelemetryTracker.shared.event(
                "detector_remote_status",
                ["status": "schema_invalid", "body": bodyString]
            )
            return []
        }
        TelemetryTracker.shared.trackDetectionRaw(route: "remote", count: encoded.items.count)
        return map(response: encoded, image: image, route: "remote")
    }

    private func buildRequest(base64: String, settings: IntentSettings) throws -> URLRequest {
        let url = URL(string: "https://api.openai.com/v1/responses")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = timeout

        let schema: [String: Any] = [
            "type": "object",
            "additionalProperties": false,
            "properties": [
                "items": [
                    "type": "array",
                    "maxItems": 8,
                    "items": [
                        "type": "object",
                        "additionalProperties": false,
                        "properties": [
                            "id": ["type": "string"],
                            "label": ["type": "string"],
                            "bbox": [
                                "type": "array",
                                "items": ["type": "number"],
                                "minItems": 4,
                                "maxItems": 4
                            ],
                            "confidence": ["type": "number", "minimum": 0, "maximum": 1]
                        ],
                        "required": ["id", "label", "bbox", "confidence"]
                    ]
                ]
            ],
            "required": ["items"]
        ]

        let maxTokens = max(1000, settings.maxTasksPerPhoto * 160)

        let body: [String: Any] = [
            "model": model,
            "text": [
                "format": [
                    "type": "json_schema",
                    "name": "remote_detection",
                    "schema": schema
                ]
            ],
            "input": [
                [
                    "role": "system",
                    "content": [[
                        "type": "input_text",
                        "text": "You are an object detector for household disposal planning. Respond with valid JSON matching: {\"items\":[{\"id\":\"str\",\"label\":\"str\",\"bbox\":[x,y,w,h],\"confidence\":0..1}]}. Coordinates must be normalized 0-1. Reply with JSON only."
                    ]]
                ],
                [
                    "role": "user",
                    "content": [
                        ["type": "input_text", "text": "Detect major household items (furniture/appliances)."],
                        [
                            "type": "input_image",
                            "image_url": "data:image/jpeg;base64,\(base64)"
                        ]
                    ]
                ]
            ],
            "max_output_tokens": maxTokens,
            "reasoning": ["effort": "low"]
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        return request
    }

    private func performRequest(request: URLRequest) async throws -> (Data, URLResponse) {
        try await URLSession.shared.data(for: request)
    }

    private func decodeResponse(_ data: Data) throws -> RemoteDetectionResponse? {
        let envelope = try JSONDecoder().decode(OpenAIResponsesEnvelope.self, from: data)
        if envelope.isIncompleteDueToMaxTokens {
            TelemetryTracker.shared.event(
                "detector_remote_status",
                ["status": "incomplete", "reason": "max_output_tokens"]
            )
            return nil
        }
        var fallbackTexts: [String] = []
        var unhandledTypes = Set<String>()

        for output in envelope.outputs {
            for content in output.content {
                switch content.type {
                case .outputJSON:
                    if let data = content.jsonData() {
                        return try JSONDecoder().decode(RemoteDetectionResponse.self, from: data)
                    }
                case .outputText:
                    if let text = content.text {
                        fallbackTexts.append(text)
                        if let textData = text.data(using: .utf8),
                           let decoded = try? JSONDecoder().decode(RemoteDetectionResponse.self, from: textData) {
                            return decoded
                        }
                    }
                default:
                    unhandledTypes.insert(content.type.identifier)
                }
            }
        }

        if !unhandledTypes.isEmpty {
            TelemetryTracker.shared.event(
                "openai_content_unhandled",
                ["types": unhandledTypes.sorted().joined(separator: ","), "route": "remote_detection"]
            )
        }

        if !fallbackTexts.isEmpty {
            TelemetryTracker.shared.event(
                "detector_remote_status",
                ["status": "text_fallback_failed", "sample": fallbackTexts.prefix(1).joined()]
            )
        }

        return nil
    }

    private func map(response: RemoteDetectionResponse, image: UIImage, route: String) -> [DetectedItem] {
        guard let cgImage = image.cgImage else { return [] }
        let width = CGFloat(cgImage.width)
        let height = CGFloat(cgImage.height)
        var sanitized: [DetectedItem] = []
        var dropped = 0

        for item in response.items {
            guard let rect = normalizeBoundingBox(item.bbox, imageWidth: width, imageHeight: height),
                  let label = sanitizeLabel(item.label),
                  let confidence = normalizeConfidence(item.confidence) else {
                dropped += 1
                continue
            }

            let identifier = sanitizeIdentifier(item.id)
            sanitized.append(
                DetectedItem(
                    id: identifier,
                    label: label,
                    confidence: confidence,
                    boundingBox: rect,
                    imageSize: CGSize(width: width, height: height)
                )
            )
        }

        TelemetryTracker.shared.trackDetectionNormalized(route: route, count: sanitized.count, dropped: dropped)
        return sanitized
    }

    private func normalizeBoundingBox(_ bbox: [Double], imageWidth: CGFloat, imageHeight: CGFloat) -> CGRect? {
        guard bbox.count == 4 else { return nil }
        let values = bbox.map { CGFloat($0) }
        guard values.allSatisfy({ $0.isFinite }) else { return nil }

        let clampedX = clamp(values[0])
        let clampedY = clamp(values[1])
        let clampedWidth = clamp(values[2])
        let clampedHeight = clamp(values[3])

        guard clampedWidth > 0, clampedHeight > 0 else { return nil }
        let maxWidth = max(0, min(1.0, clampedWidth + clampedX) - clampedX)
        let maxHeight = max(0, min(1.0, clampedHeight + clampedY) - clampedY)
        guard maxWidth > 0, maxHeight > 0 else { return nil }

        return CGRect(
            x: clampedX * imageWidth,
            y: clampedY * imageHeight,
            width: maxWidth * imageWidth,
            height: maxHeight * imageHeight
        )
    }

    private func normalizeConfidence(_ confidence: Double) -> Double? {
        guard confidence.isFinite else { return nil }
        let clamped = min(max(confidence, 0), 1)
        return clamped >= 0.05 ? clamped : nil
    }

    private func sanitizeIdentifier(_ id: String) -> UUID {
        if let uuid = UUID(uuidString: id.uppercased()) {
            return uuid
        }
        let trimmed = id.trimmingCharacters(in: .whitespacesAndNewlines)
        if let uuid = UUID(uuidString: trimmed.uppercased()) {
            return uuid
        }
        return UUID()
    }

    private func sanitizeLabel(_ rawLabel: String) -> String? {
        let trimmed = rawLabel.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let withoutNewlines = trimmed.replacingOccurrences(of: "\n", with: " ")
        let folded = withoutNewlines.folding(options: [.diacriticInsensitive, .widthInsensitive], locale: .current)
        let allowed = CharacterSet.alphanumerics
            .union(.whitespaces)
            .union(CharacterSet(charactersIn: "-_/"))

        var scalarView = String.UnicodeScalarView()
        scalarView.reserveCapacity(folded.unicodeScalars.count)
        let spaceScalar: UnicodeScalar = " ".unicodeScalars.first!
        for scalar in folded.unicodeScalars {
            if allowed.contains(scalar) {
                scalarView.append(scalar)
            } else {
                scalarView.append(spaceScalar)
            }
        }
        let filtered = String(scalarView)
        let components = filtered.split(whereSeparator: { $0.isWhitespace })
        guard !components.isEmpty else { return nil }
        let normalized = components.joined(separator: " ")
        let limited = String(normalized.prefix(48))
        let cased = limited.lowercased().capitalized
        return cased.isEmpty ? nil : cased
    }

    private func clamp(_ value: CGFloat) -> CGFloat {
        if value.isNaN { return 0 }
        return min(max(value, 0), 1)
    }

    private func retryAfterInterval(from response: HTTPURLResponse) -> TimeInterval? {
        guard let header = response.value(forHTTPHeaderField: "Retry-After") else { return nil }
        if let seconds = TimeInterval(header) { return seconds }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "EEE',' dd MMM yyyy HH:mm:ss z"
        if let date = formatter.date(from: header) {
            return max(0, date.timeIntervalSinceNow)
        }
        return nil
    }
}

private extension UIImage {
    func resized(maxDimension: CGFloat) -> UIImage {
        let maxSide = max(size.width, size.height)
        guard maxSide > maxDimension else { return self }
        let scale = maxDimension / maxSide
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        UIGraphicsBeginImageContextWithOptions(newSize, true, 1.0)
        draw(in: CGRect(origin: .zero, size: newSize))
        let scaled = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return scaled ?? self
    }

    func strippedJPEGData(quality: CGFloat) -> Data? {
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        let image = renderer.image { _ in
            self.draw(in: CGRect(origin: .zero, size: size))
        }
        return image.jpegData(compressionQuality: quality)
    }
}
