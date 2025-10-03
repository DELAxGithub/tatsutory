import Foundation
import UIKit

class OpenAIService {
    private let apiKey: String
    private let model = "gpt-5-mini"
    private let timeout: TimeInterval = 45.0

    private struct RequestLogMeta {
        let id = UUID().uuidString
        let start = Date()
        let path: String
        let bodyBytes: Int
    }

    init(apiKey: String) {
        self.apiKey = apiKey
    }

    struct TaskPlanResponse: Codable {
        let tasks: [TaskItem]

        struct TaskItem: Codable {
            let id: String
            let title: String
            let category: String?
            let exitTag: String
            let checklist: [String]?
            let tips: String?
            let links: [String]?
            let estimatedMinutes: Int?
            let note: String?
        }
    }

    struct Response {
        let tasks: [TidyTask]
        let requestId: String?
    }

    func generateTasks(from items: [DetectedItem],
                       settings: IntentSettings,
                       locale: UserLocale) async throws -> Response {
        let prompts = PromptBuilder.build(items: items, settings: settings, locale: locale)
        let request = try buildRequest(prompts: prompts, itemCount: items.count)
        let meta = RequestLogMeta(path: request.url?.path ?? "", bodyBytes: request.httpBody?.count ?? 0)
        logRequest(meta)
        let (data, requestId) = try await performRequest(request, meta: meta)
        let tasks = try parseTaskResponse(data, settings: settings, locale: locale)
        return Response(tasks: tasks, requestId: requestId)
    }

    private func buildRequest(prompts: (system: String, user: String), itemCount: Int) throws -> URLRequest {
        let url = URL(string: "https://api.openai.com/v1/responses")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = timeout

        let body = createRequestBody(prompts: prompts, itemCount: itemCount)
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        return request
    }

    private func createRequestBody(prompts: (system: String, user: String), itemCount: Int) -> [String: Any] {
        let messages: [[String: Any]] = [
            [
                "role": "system",
                "content": [["type": "input_text", "text": prompts.system]]
            ],
            [
                "role": "user",
                "content": [["type": "input_text", "text": prompts.user]]
            ]
        ]

        let schemaDict = parseJSONSchema(PromptBuilder.schema(for: itemCount))

        #if DEBUG
        // Log schema to verify minItems/maxItems are set correctly
        if let schemaData = try? JSONSerialization.data(withJSONObject: schemaDict, options: .prettyPrinted),
           let schemaString = String(data: schemaData, encoding: .utf8) {
            print("📋 SCHEMA (itemCount=\(itemCount)):")
            print(schemaString.prefix(1000))
        }
        #endif

        return [
            "model": model,
            "input": messages,
            "text": [
                "format": [
                    "type": "json_schema",
                    "name": "task_plan",
                    "schema": schemaDict
                ]
            ],
            "max_output_tokens": 2500,
            "reasoning": ["effort": "low"]
        ]
    }

    private func parseJSONSchema(_ schemaString: String) -> [String: Any] {
        guard let data = schemaString.data(using: .utf8),
              let schema = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return [:]
        }
        return schema
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
            TelemetryTracker.shared.event("ai_enrichment_attempt", ["status": "network_error"])
            throw TatsuToriError.networkError(error)
        }
        let (data, response) = result
        guard let httpResponse = response as? HTTPURLResponse else {
            logResponse(meta, response: nil, requestId: nil, error: nil)
            TelemetryTracker.shared.event("ai_enrichment_attempt", ["status": "invalid_response"])
            throw TatsuToriError.networkError(NSError(domain: "HTTP", code: -1))
        }
        let requestId = httpResponse.value(forHTTPHeaderField: "x-request-id")
        logResponse(meta, response: httpResponse, requestId: requestId, error: nil)
        guard 200...299 ~= httpResponse.statusCode else {
            if httpResponse.statusCode == 429 {
                TelemetryTracker.shared.event("ai_enrichment_rate_limited", [:])
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
            TelemetryTracker.shared.event("ai_enrichment_attempt", ["status": "http_\(httpResponse.statusCode)"])
            throw TatsuToriError.networkError(NSError(domain: "HTTP", code: httpResponse.statusCode))
        }
        TelemetryTracker.shared.event("ai_enrichment_success", [:])
        return (data, requestId)
    }

    private func parseTaskResponse(_ data: Data, settings: IntentSettings, locale: UserLocale) throws -> [TidyTask] {
        let envelope = try JSONDecoder().decode(OpenAIResponsesEnvelope.self, from: data)
        var fallbackTexts: [String] = []
        var unhandledTypes = Set<String>()

        #if DEBUG
        print("🔍 PARSING RESPONSE: \(envelope.outputs.count) outputs")
        #endif

        for output in envelope.outputs {
            #if DEBUG
            print("🔍 OUTPUT: \(output.content.count) content items")
            #endif

            for content in output.content {
                #if DEBUG
                print("🔍 CONTENT TYPE: \(content.type.identifier)")
                #endif

                switch content.type {
                case .outputJSON:
                    #if DEBUG
                    if let jsonData = content.jsonData(),
                       let jsonString = String(data: jsonData, encoding: .utf8) {
                        print("📦 JSON CONTENT:")
                        print(jsonString.prefix(2000))
                    }
                    #endif

                    if let jsonData = content.jsonData() {
                        let response = try JSONDecoder().decode(TaskPlanResponse.self, from: jsonData)
                        return convertToTidyTasks(response.tasks, settings: settings, locale: locale)
                    }
                case .outputText:
                    #if DEBUG
                    if let text = content.text {
                        print("📝 TEXT CONTENT:")
                        print(text.prefix(2000))
                    }
                    #endif

                    if let text = content.text,
                       let planData = text.data(using: .utf8),
                       let response = try? JSONDecoder().decode(TaskPlanResponse.self, from: planData) {
                        return convertToTidyTasks(response.tasks, settings: settings, locale: locale)
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
                ["types": unhandledTypes.sorted().joined(separator: ","), "route": "task_planner"]
            )
        }

        if !fallbackTexts.isEmpty {
            TelemetryTracker.shared.event(
                "ai_enrichment_parse_failed",
                ["sample": String(fallbackTexts.prefix(1).joined().prefix(256))]
            )
        }

        TelemetryTracker.shared.event("ai_enrichment_attempt", ["status": "parse_failed"])
        throw TatsuToriError.invalidJSON
    }

    private func convertToTidyTasks(_ taskItems: [TaskPlanResponse.TaskItem], settings: IntentSettings, locale: UserLocale) -> [TidyTask] {
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime]
        let goalDate = isoFormatter.date(from: settings.goalDateISO) ?? Date()

        var validTasks: [TidyTask] = []
        for item in taskItems {
            guard let exitTag = ExitTag(rawValue: item.exitTag) else {
                continue
            }

            // Calculate due date based on goalDate and exitTag offset
            let offset = DueDateHelper.offset(for: exitTag)
            let dueDate = Calendar.current.date(byAdding: .day, value: offset, to: goalDate) ?? goalDate
            let dueAtISO = isoFormatter.string(from: dueDate)

            let task = TidyTask(
                id: item.id,
                title: item.title,
                category: item.category,
                note: item.note,
                tips: item.tips,
                area: nil,
                exit_tag: exitTag,
                priority: nil,
                effort_min: item.estimatedMinutes,
                labels: nil,
                checklist: item.checklist,
                links: item.links,
                url: item.links?.first,
                due_at: dueAtISO,
                photoAssetID: nil
            )
            validTasks.append(task)
        }
        return validTasks
    }
}

/// Helper for due date offset calculation based on exit tag
private enum DueDateHelper {
    static func offset(for exitTag: ExitTag) -> Int {
        switch exitTag {
        case .sell: return -7   // 1週間前
        case .give: return -5   // 5日前
        case .recycle: return -3  // 3日前
        case .trash: return -2  // 2日前
        case .keep: return -1   // 前日
        }
    }
}
