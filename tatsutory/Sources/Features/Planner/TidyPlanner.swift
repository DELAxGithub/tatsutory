import Foundation
import UIKit

class TidyPlanner {
    private let settingsStore: IntentSettingsStore
    private let splitService: PhotoSplitService
    private static let enrichmentGate = ConcurrencyGate()

    init(settingsStore: IntentSettingsStore = .shared,
         splitService: PhotoSplitService = PhotoSplitService()) {
        self.settingsStore = settingsStore
        self.splitService = splitService
    }

    func generate(from image: UIImage, allowNetwork: Bool) async -> PlanResult {
        let settings = settingsStore.value
        let locale = Self.locale(for: settings.region)
        let detection = await splitService.detectItems(in: image, settings: settings, allowNetwork: allowNetwork)
        let detectionNotice = detection.errorMessage
        let filteredItems = IntentAdjuster.filter(items: detection.items, settings: settings)
        TelemetryTracker.shared.trackDetection(duration: detection.processingTime, itemCount: filteredItems.count, usedFallback: detection.usedFallback)

        guard !filteredItems.isEmpty else {
            TelemetryTracker.shared.trackAIEnrichmentSkip(reason: .noDetectedItems)
            let fallback = TaskComposer.fallbackPlan(settings: settings, locale: locale)
            return PlanResult(plan: fallback, source: .local, notice: detectionNotice)
        }

        let blueprints = TaskComposer.makeBlueprints(settings: settings, locale: locale, items: filteredItems)
        var tasks = TaskComposer.tasks(from: blueprints)
        var plan = Plan(project: L10n.string("plan.project_name"), locale: locale, tasks: tasks).validated()
        var source: PlanSource = .local

        guard FeatureFlags.intentSettingsV1 else {
            return PlanResult(plan: plan, source: source, notice: detectionNotice)
        }

        let apiKey = Secrets.load()
        guard !apiKey.isEmpty else {
            TelemetryTracker.shared.trackAIEnrichmentSkip(reason: .missingAPIKey)
            return PlanResult(plan: plan, source: source, notice: detectionNotice)
        }

        guard settings.llm.consent else {
            TelemetryTracker.shared.trackAIEnrichmentSkip(reason: .consentOff)
            return PlanResult(plan: plan, source: source, notice: detectionNotice)
        }

        guard allowNetwork else {
            TelemetryTracker.shared.trackAIEnrichmentSkip(reason: .networkDisallowed)
            return PlanResult(plan: plan, source: source, notice: detectionNotice)
        }

        do {
            await TidyPlanner.enrichmentGate.acquire()
            defer { Task { await TidyPlanner.enrichmentGate.release() } }
            let result = try await enrichWithBackoff(apiKey: apiKey,
                                                     image: image,
                                                     settings: settings,
                                                     locale: locale,
                                                     scheduled: tasks,
                                                     blueprints: blueprints)
            switch result {
            case .success(let outcome):
                tasks = outcome.tasks
                plan = Plan(project: L10n.string("plan.project_name"), locale: locale, tasks: tasks).validated()
                source = .openAI(requestId: outcome.requestId ?? "-")
            case .rateLimited:
                source = .rateLimited
            case .failed:
                break
            }
        } catch {
            print("OpenAI enrichment failed: \(error)")
        }

        return PlanResult(plan: plan, source: source, notice: detectionNotice)
    }

    private enum EnrichmentResult {
        case success(tasks: [TidyTask], requestId: String?)
        case rateLimited
        case failed
    }

    private func enrichWithBackoff(apiKey: String,
                                   image: UIImage,
                                   settings: IntentSettings,
                                   locale: UserLocale,
                                   scheduled: [TidyTask],
                                   blueprints: [TaskComposer.Blueprint]) async throws -> EnrichmentResult {
        let planner = OpenAIService(apiKey: apiKey)
        let prompts = PromptBuilder.build(settings: settings, locale: locale, blueprints: blueprints)
        let maxAttempts = 3
        let enrichmentId = UUID().uuidString
        var sawRateLimit = false

        for attempt in 0..<maxAttempts {
            let attemptNumber = attempt + 1
            TelemetryTracker.shared.trackAIEnrichmentAttempt(id: enrichmentId, attempt: attemptNumber)
            do {
                let response = try await planner.generatePlan(from: image, prompts: prompts)
                TelemetryTracker.shared.trackAIEnrichmentResult(id: enrichmentId, success: true, attempt: attemptNumber, requestId: response.requestId, status: 200)
                let merged = mergePlan(response.plan, with: scheduled)
                return .success(tasks: merged, requestId: response.requestId)
            } catch TatsuToriError.rateLimited(let retryAfter) {
                TelemetryTracker.shared.trackAIEnrichmentRateLimit(id: enrichmentId, attempt: attemptNumber, retryAfter: retryAfter)
                let baseDelay = retryAfter ?? pow(2.0, Double(attempt))
                let delay = baseDelay + Double.random(in: 0...0.4)
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                sawRateLimit = true
                continue
            } catch {
                TelemetryTracker.shared.trackAIEnrichmentResult(id: enrichmentId, success: false, attempt: attemptNumber)
                throw error
            }
        }

        TelemetryTracker.shared.trackAIEnrichmentResult(id: enrichmentId, success: false, attempt: maxAttempts)
        return sawRateLimit ? .rateLimited : .failed
    }

    private func mergePlan(_ remotePlan: Plan, with scheduledTasks: [TidyTask]) -> [TidyTask] {
        var scheduledById = Dictionary(uniqueKeysWithValues: scheduledTasks.map { ($0.id, $0) })
        var merged: [TidyTask] = []

        for remote in remotePlan.tasks {
            guard let scheduled = scheduledById.removeValue(forKey: remote.id) else { continue }
            let title = sanitizeTitle(remote.title, fallback: scheduled.title)
            let note = sanitizeNote(remote.note ?? scheduled.note)
            let checklist = sanitizeList(remote.checklist ?? scheduled.checklist)
            let links = sanitizeList(remote.links ?? scheduled.links)

            let mergedTask = TidyTask(
                id: scheduled.id,
                title: title,
                note: note,
                area: scheduled.area,
                exit_tag: scheduled.exit_tag,
                priority: scheduled.priority,
                effort_min: scheduled.effort_min,
                labels: scheduled.labels,
                checklist: checklist,
                links: links,
                url: scheduled.url,
                due_at: scheduled.due_at
            )
            merged.append(mergedTask)
        }

        merged.append(contentsOf: scheduledById.values)
        return merged.isEmpty ? scheduledTasks : merged
    }

    private func sanitizeTitle(_ title: String?, fallback: String) -> String {
        guard let title = title?.trimmingCharacters(in: .whitespacesAndNewlines), !title.isEmpty else {
            return fallback
        }
        return String(title.prefix(80))
    }

    private func sanitizeNote(_ note: String?) -> String? {
        guard let note = note?.trimmingCharacters(in: .whitespacesAndNewlines), !note.isEmpty else {
            return nil
        }
        return note
    }

    private func sanitizeList(_ values: [String]?) -> [String]? {
        guard let values = values else { return nil }
        var seen = Set<String>()
        var result: [String] = []
        for value in values {
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            if seen.insert(trimmed).inserted {
                result.append(trimmed)
            }
        }
        return result.isEmpty ? nil : result
    }

    static func fallbackPlan() -> Plan {
        return FallbackPlanner.generatePlan()
    }

    private static func locale(for region: String) -> UserLocale {
        switch region {
        case "JP": return UserLocale(country: "JP", city: "Tokyo")
        case "CA-TO": return UserLocale(country: "CA", city: "Toronto")
        default: return UserLocale(country: "US", city: "San Francisco")
        }
    }
}

private actor ConcurrencyGate {
    private var isAvailable = true
    
    func acquire() async {
        while !isAvailable {
            await Task.yield()
        }
        isAvailable = false
    }
    
    func release() {
        isAvailable = true
    }
}

#if DEBUG
extension TidyPlanner {
    static func debugForceEnrichmentTest() async -> String {
        let apiKey = Secrets.load()
        guard !apiKey.isEmpty else { return "Missing API key" }
        let consentStore = ConsentStore.shared
        let originalConsent = consentStore.hasConsentedToVisionUpload
        if !originalConsent {
            consentStore.hasConsentedToVisionUpload = true
        }
        let service = OpenAIService(apiKey: apiKey)
        let locale = UserLocale(country: "CA", city: "Toronto")
        let prompts = PromptBuilder.build(settings: IntentSettingsStore.shared.value,
                                          locale: locale,
                                          blueprints: [])
        let image = debugSolidImage()
        do {
            let response = try await service.generatePlan(from: image, prompts: prompts)
            if !originalConsent {
                consentStore.hasConsentedToVisionUpload = false
            }
            return "Success reqId=\(response.requestId ?? "-") tasks=\(response.plan.tasks.count)"
        } catch {
            if !originalConsent {
                consentStore.hasConsentedToVisionUpload = false
            }
            return "Error: \(error.localizedDescription)"
        }
    }
    
    private static func debugSolidImage() -> UIImage {
        let size = CGSize(width: 32, height: 32)
        UIGraphicsBeginImageContextWithOptions(size, true, 1.0)
        UIColor.systemOrange.setFill()
        UIRectFill(CGRect(origin: .zero, size: size))
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return image ?? UIImage()
    }
}
#endif
