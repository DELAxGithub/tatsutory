import Foundation
import UIKit

class OpenAIService {
    private let apiKey: String
    private let model = "gpt-5-mini-vision"
    private let timeout: TimeInterval = 30.0
    
    private struct RequestLogMeta {
        let id = UUID().uuidString
        let start = Date()
        let path: String
        let bodyBytes: Int
    }

    init(apiKey: String) {
        self.apiKey = apiKey
    }
    
    struct Response {
        let plan: Plan
        let requestId: String?
    }

    func generatePlan(from image: UIImage, prompts: (system: String, developer: String, data: String)) async throws -> Response {
        guard let base64Image = image.toBase64() else {
            throw TatsuToriError.planningFailed
        }
        
        let request = try buildRequest(base64Image: base64Image, prompts: prompts)
        let meta = RequestLogMeta(path: request.url?.path ?? "", bodyBytes: request.httpBody?.count ?? 0)
        logRequest(meta)
        let (data, requestId) = try await performRequest(request, meta: meta)
        let plan = try parsePlanResponse(data)
        return Response(plan: plan, requestId: requestId)
    }
    
    private func buildRequest(base64Image: String, prompts: (system: String, developer: String, data: String)) throws -> URLRequest {
        let url = URL(string: "https://api.openai.com/v1/responses")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = timeout
        
        let body = createRequestBody(base64Image: base64Image, prompts: prompts)
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        return request
    }
    
    private func createRequestBody(base64Image: String, prompts: (system: String, developer: String, data: String)) -> [String: Any] {
        let messages: [[String: Any]] = [
            [
                "role": "system",
                "content": [["type": "input_text", "text": prompts.system]]
            ],
            [
                "role": "developer",
                "content": [["type": "input_text", "text": prompts.developer]]
            ],
            [
                "role": "user",
                "content": [
                    ["type": "input_text", "text": prompts.data],
                    [
                        "type": "input_image",
                        "image_url": "data:image/jpeg;base64,\(base64Image)"
                    ]
                ]
            ]
        ]
        
        return [
            "model": model,
            "input": messages,
            "text": [
                "format": [
                    "type": "json_schema",
                    "name": "tidy_plan",
                    "schema": TidySchema.jsonSchema
                ]
            ],
            "max_output_tokens": 2000
        ]
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
    
    private func logRequest(_ meta: RequestLogMeta) {
        #if DEBUG
        print("OPENAI REQ id=\(meta.id) path=\(meta.path) size=\(meta.bodyBytes)B ts=\(meta.start.timeIntervalSince1970)")
        #endif
    }
    
    private func logResponse(_ meta: RequestLogMeta, response: HTTPURLResponse?, requestId: String?, error: Error?) {
        #if DEBUG
        let duration = Int(Date().timeIntervalSince(meta.start) * 1000)
        let status = response?.statusCode ?? -1
        print("OPENAI RES id=\(meta.id) status=\(status) reqId=\(requestId ?? "-") dt=\(duration)ms err=\(error.map { "\($0)" } ?? "nil")")
        #endif
    }
    
    private func performRequest(_ request: URLRequest, meta: RequestLogMeta) async throws -> (Data, String?) {
        let session = URLSession.shared
        let result: (Data, URLResponse)
        do {
            result = try await session.data(for: request)
        } catch {
            logResponse(meta, response: nil, requestId: nil, error: error)
            throw TatsuToriError.networkError(error)
        }
        let (data, response) = result
        guard let httpResponse = response as? HTTPURLResponse else {
            logResponse(meta, response: nil, requestId: nil, error: nil)
            throw TatsuToriError.networkError(NSError(domain: "HTTP", code: -1))
        }
        let requestId = httpResponse.value(forHTTPHeaderField: "x-request-id")
        logResponse(meta, response: httpResponse, requestId: requestId, error: nil)
        guard 200...299 ~= httpResponse.statusCode else {
            if httpResponse.statusCode == 429 {
                let retryAfter = retryAfterInterval(from: httpResponse)
                throw TatsuToriError.rateLimited(retryAfter: retryAfter)
            }
            if let bodyString = String(data: data, encoding: .utf8) {
                TelemetryTracker.shared.event(
                    "openai_response_error",
                    [
                        "status": "\(httpResponse.statusCode)",
                        "body": String(bodyString.prefix(512))
                    ]
                )
            }
            throw TatsuToriError.networkError(NSError(domain: "HTTP", code: httpResponse.statusCode))
        }
        return (data, requestId)
    }
    
    private func parsePlanResponse(_ data: Data) throws -> Plan {
        let envelope = try JSONDecoder().decode(OpenAIResponsesEnvelope.self, from: data)
        var fallbackTexts: [String] = []
        var unhandledTypes = Set<String>()

        for output in envelope.outputs {
            for content in output.content {
                switch content.type {
                case .outputJSON:
                    if let jsonData = content.jsonData() {
                        let plan = try JSONDecoder().decode(Plan.self, from: jsonData)
                        guard PlanValidator.isValid(plan) else {
                            throw TatsuToriError.invalidJSON
                        }
                        return plan.validated()
                    }
                case .outputText:
                    if let text = content.text,
                       let planData = text.data(using: .utf8),
                       let plan = try? JSONDecoder().decode(Plan.self, from: planData),
                       PlanValidator.isValid(plan) {
                        return plan.validated()
                    } else if let text = content.text {
                        fallbackTexts.append(text)
                    }
                default:
                    unhandledTypes.insert(content.type.identifier)
                }
            }
        }

        if !unhandledTypes.isEmpty {
            TelemetryTracker.shared.event(
                "openai_content_unhandled",
                ["types": unhandledTypes.sorted().joined(separator: ","), "route": "planner"]
            )
        }

        if !fallbackTexts.isEmpty {
            TelemetryTracker.shared.event(
                "ai_enrichment_parse_failed",
                ["sample": String(fallbackTexts.prefix(1).joined().prefix(256))]
            )
        }

        throw TatsuToriError.invalidJSON
    }
    
}

// MARK: - Plan Validation Helpers

enum PlanValidator {
    static func isValid(_ plan: Plan) -> Bool {
        plan.tasks.allSatisfy { task in
            !task.id.isEmpty && !task.title.isEmpty
        }
    }
}

private extension UIImage {
    func toBase64(maxDimension: CGFloat = 1024, quality: CGFloat = 0.7) -> String? {
        guard let scaled = resizedIfNeeded(maxDimension: maxDimension),
              let data = scaled.jpegData(compressionQuality: quality) else {
            return nil
        }
        return data.base64EncodedString()
    }

    private func resizedIfNeeded(maxDimension: CGFloat) -> UIImage? {
        let longestSide = max(size.width, size.height)
        guard longestSide > maxDimension else { return self }
        let scale = maxDimension / longestSide
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        UIGraphicsBeginImageContextWithOptions(newSize, true, 1.0)
        defer { UIGraphicsEndImageContext() }
        draw(in: CGRect(origin: .zero, size: newSize))
        return UIGraphicsGetImageFromCurrentImageContext()
    }
}
