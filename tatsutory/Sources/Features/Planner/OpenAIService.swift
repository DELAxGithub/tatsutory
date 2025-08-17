import Foundation
import UIKit

class OpenAIService {
    private let apiKey: String
    private let model = "gpt-4o"
    private let timeout: TimeInterval = 30.0
    
    init(apiKey: String) {
        self.apiKey = apiKey
    }
    
    func generatePlan(from image: UIImage, locale: UserLocale) async throws -> Plan {
        guard let base64Image = image.toBase64() else {
            throw TatsuToriError.planningFailed
        }
        
        let request = try buildRequest(base64Image: base64Image, locale: locale)
        let data = try await performRequest(request)
        return try parsePlanResponse(data)
    }
    
    private func buildRequest(base64Image: String, locale: UserLocale) throws -> URLRequest {
        let url = URL(string: "https://api.openai.com/v1/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = timeout
        
        let body = createRequestBody(base64Image: base64Image, locale: locale)
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        return request
    }
    
    private func createRequestBody(base64Image: String, locale: UserLocale) -> [String: Any] {
        let messages = [
            [
                "role": "user",
                "content": [
                    [
                        "type": "text",
                        "text": createPrompt(for: locale)
                    ],
                    [
                        "type": "image_url",
                        "image_url": [
                            "url": "data:image/jpeg;base64,\(base64Image)"
                        ]
                    ]
                ]
            ]
        ]
        
        return [
            "model": model,
            "messages": messages,
            "response_format": [
                "type": "json_schema",
                "json_schema": [
                    "name": "tidy_plan",
                    "schema": TidySchema.jsonSchema
                ]
            ],
            "max_tokens": 2000
        ]
    }
    
    private func performRequest(_ request: URLRequest) async throws -> Data {
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              200...299 ~= httpResponse.statusCode else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
            throw TatsuToriError.networkError(NSError(domain: "HTTP", code: statusCode))
        }
        
        return data
    }
    
    private func parsePlanResponse(_ data: Data) throws -> Plan {
        let openAIResponse = try JSONDecoder().decode(OpenAIResponse.self, from: data)
        
        guard let content = openAIResponse.choices.first?.message.content else {
            throw TatsuToriError.invalidJSON
        }
        
        let planData = content.data(using: .utf8)!
        let plan = try JSONDecoder().decode(Plan.self, from: planData)
        
        return plan.validated()
    }
    
    private func createPrompt(for locale: UserLocale) -> String {
        return """
        You are a move-out concierge. Analyze this photo and create actionable tasks for getting rid of items. 

        Rules:
        - Each task must have an exit_tag: SELL, GIVE, RECYCLE, TRASH, or KEEP
        - Tasks should be 5-25 minutes each
        - Include specific steps in checklist
        - Add relevant links for \(locale.city), \(locale.country)
        - Priority 1-4 (4=urgent)
        - Set realistic due dates

        Focus on what needs to go, not what to organize. Return JSON only.
        """
    }
}

// MARK: - OpenAI Response Models

private struct OpenAIResponse: Codable {
    let choices: [Choice]
    
    struct Choice: Codable {
        let message: Message
    }
    
    struct Message: Codable {
        let content: String
    }
}