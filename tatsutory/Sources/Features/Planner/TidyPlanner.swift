import Foundation
import UIKit

class TidyPlanner {
    private let settingsStore: IntentSettingsStore
    private let splitService: PhotoSplitService
    private static let enrichmentGate = ConcurrencyGate()

    typealias ProgressCallback = @MainActor (String) -> Void

    init(settingsStore: IntentSettingsStore = .shared,
         splitService: PhotoSplitService = PhotoSplitService()) {
        self.settingsStore = settingsStore
        self.splitService = splitService
    }

    func generate(from image: UIImage, allowNetwork: Bool, photoAssetID: String? = nil, onProgress: ProgressCallback? = nil) async -> PlanResult {
        let settings = settingsStore.value
        let locale = Self.locale(for: settings.region)

        // Step 1: Detect items in the image
        await onProgress?(L10n.string("main.progress.analyzing_photo"))
        let detection = await splitService.detectItems(in: image, settings: settings, allowNetwork: allowNetwork)
        let detectionNotice = detection.errorMessage
        let filteredItems = IntentAdjuster.filter(items: detection.items, settings: settings)

        TelemetryTracker.shared.trackDetection(
            duration: detection.processingTime,
            itemCount: filteredItems.count,
            usedFallback: detection.usedFallback
        )

        // If no items detected, return minimal fallback
        guard !filteredItems.isEmpty else {
            TelemetryTracker.shared.trackAIEnrichmentSkip(reason: .noDetectedItems)
            let fallback = TaskComposer.fallbackPlan(settings: settings, locale: locale, itemCount: 0, photoAssetID: photoAssetID)
            return PlanResult(plan: fallback, source: .local, notice: detectionNotice)
        }

        // Step 2: Try to generate tasks via LLM
        let apiKey = Secrets.load()
        let shouldUseLLM = FeatureFlags.intentSettingsV1
            && !apiKey.isEmpty
            && settings.llm.consent
            && allowNetwork

        guard shouldUseLLM else {
            // Skip LLM - return fallback
            if apiKey.isEmpty {
                TelemetryTracker.shared.trackAIEnrichmentSkip(reason: .missingAPIKey)
            } else if !settings.llm.consent {
                TelemetryTracker.shared.trackAIEnrichmentSkip(reason: .consentOff)
            } else if !allowNetwork {
                TelemetryTracker.shared.trackAIEnrichmentSkip(reason: .networkDisallowed)
            }

            let fallback = TaskComposer.fallbackPlan(settings: settings, locale: locale, itemCount: filteredItems.count, photoAssetID: photoAssetID)
            return PlanResult(plan: fallback, source: .local, notice: detectionNotice)
        }

        // Step 3: Use LLM to generate item-specific tasks
        await onProgress?(L10n.string("main.progress.generating_tasks"))
        do {
            await TidyPlanner.enrichmentGate.acquire()
            defer { Task { await TidyPlanner.enrichmentGate.release() } }

            let result = try await generateWithLLM(
                items: filteredItems,
                apiKey: apiKey,
                settings: settings,
                locale: locale
            )

            switch result {
            case .success(let tasks, let requestId):
                // Add photoAssetID to all LLM-generated tasks
                let tasksWithPhoto = tasks.map { task in
                    TidyTask(
                        id: task.id,
                        title: task.title,
                        category: task.category,
                        note: task.note,
                        tips: task.tips,
                        area: task.area,
                        exit_tag: task.exit_tag,
                        priority: task.priority,
                        effort_min: task.effort_min,
                        labels: task.labels,
                        checklist: task.checklist,
                        links: task.links,
                        url: task.url,
                        due_at: task.due_at,
                        photoAssetID: photoAssetID
                    )
                }
                let plan = Plan(
                    project: L10n.string("plan.project_name"),
                    locale: locale,
                    tasks: tasksWithPhoto
                ).validated()
                return PlanResult(
                    plan: plan,
                    source: .openAI(requestId: requestId ?? "-"),
                    notice: detectionNotice
                )

            case .rateLimited:
                let fallback = TaskComposer.fallbackPlan(settings: settings, locale: locale, itemCount: filteredItems.count, photoAssetID: photoAssetID)
                return PlanResult(plan: fallback, source: .rateLimited, notice: detectionNotice)

            case .failed:
                let fallback = TaskComposer.fallbackPlan(settings: settings, locale: locale, itemCount: filteredItems.count, photoAssetID: photoAssetID)
                return PlanResult(plan: fallback, source: .local, notice: detectionNotice)
            }
        } catch {
            print("TidyPlanner: LLM generation failed: \(error)")
            let fallback = TaskComposer.fallbackPlan(settings: settings, locale: locale, itemCount: filteredItems.count, photoAssetID: photoAssetID)
            return PlanResult(plan: fallback, source: .local, notice: detectionNotice)
        }
    }

    private enum LLMResult {
        case success([TidyTask], String?)
        case rateLimited
        case failed
    }

    private func generateWithLLM(
        items: [DetectedItem],
        apiKey: String,
        settings: IntentSettings,
        locale: UserLocale
    ) async throws -> LLMResult {
        let service = OpenAIService(apiKey: apiKey)
        let maxAttempts = 3
        let enrichmentId = UUID().uuidString
        var sawRateLimit = false

        for attempt in 0..<maxAttempts {
            let attemptNumber = attempt + 1
            TelemetryTracker.shared.trackAIEnrichmentAttempt(id: enrichmentId, attempt: attemptNumber)

            do {
                let response = try await service.generateTasks(
                    from: items,
                    settings: settings,
                    locale: locale
                )

                TelemetryTracker.shared.trackAIEnrichmentResult(
                    id: enrichmentId,
                    success: true,
                    attempt: attemptNumber,
                    requestId: response.requestId,
                    status: 200
                )

                return .success(response.tasks, response.requestId)

            } catch TatsuToriError.rateLimited(let retryAfter) {
                TelemetryTracker.shared.trackAIEnrichmentRateLimit(
                    id: enrichmentId,
                    attempt: attemptNumber,
                    retryAfter: retryAfter
                )

                let baseDelay = retryAfter ?? pow(2.0, Double(attempt))
                let delay = baseDelay + Double.random(in: 0...0.4)
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                sawRateLimit = true
                continue

            } catch {
                TelemetryTracker.shared.trackAIEnrichmentResult(
                    id: enrichmentId,
                    success: false,
                    attempt: attemptNumber
                )
                throw error
            }
        }

        TelemetryTracker.shared.trackAIEnrichmentResult(
            id: enrichmentId,
            success: false,
            attempt: maxAttempts
        )
        return sawRateLimit ? .rateLimited : .failed
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
        let settings = IntentSettingsStore.shared.value

        // Create sample detected items
        let sampleItems = [
            DetectedItem(
                id: UUID(),
                label: "Soundbar",
                confidence: 0.9,
                boundingBox: CGRect(x: 0, y: 0, width: 100, height: 50),
                imageSize: CGSize(width: 200, height: 200)
            )
        ]

        do {
            let response = try await service.generateTasks(
                from: sampleItems,
                settings: settings,
                locale: locale
            )

            if !originalConsent {
                consentStore.hasConsentedToVisionUpload = false
            }

            return "Success reqId=\(response.requestId ?? "-") tasks=\(response.tasks.count)"
        } catch {
            if !originalConsent {
                consentStore.hasConsentedToVisionUpload = false
            }
            return "Error: \(error.localizedDescription)"
        }
    }
}
#endif
