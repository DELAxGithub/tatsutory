import Foundation
import UIKit

class TidyPlanner {
    private let intentStore: IntentSettingsStore
    private let consentStore: ConsentStore
    private let splitService: PhotoSplitService
    
    init(intentStore: IntentSettingsStore = .shared,
         consentStore: ConsentStore = .shared,
         splitService: PhotoSplitService = PhotoSplitService()) {
        self.intentStore = intentStore
        self.consentStore = consentStore
        self.splitService = splitService
    }
    
    func generate(from image: UIImage, locale: UserLocale, allowNetwork: Bool) async -> Plan {
        let intent = intentStore.currentIntent
        let goalDate = intentStore.goalDate
        let detection = await splitService.detectItems(in: image)
        let filteredItems = IntentAdjuster(intent: intent).filter(items: detection.items)
        TelemetryTracker.shared.trackDetection(duration: detection.processingTime, itemCount: filteredItems.count, usedFallback: detection.usedFallback)
        let composer = TaskComposer(locale: locale, intent: intent, goalDate: goalDate)
        var tasks = composer.buildTasks(from: filteredItems)
        
        if tasks.isEmpty {
            let fallback = FallbackPlanner.generatePlan(locale: locale)
            return fallback
        }
        
        let apiKey = Secrets.load()
        if !consentStore.hasConsentedToVisionUpload || !allowNetwork || apiKey.isEmpty {
            // No remote enhancements; tasks already composed locally
            return Plan(project: "TatsuTori Photo Split", locale: locale, tasks: tasks).validated()
        }
        
        // Optional: enrich tasks via OpenAI for notes/links while respecting consent
        do {
            let planner = OpenAIService(apiKey: apiKey)
            let enriched = try await planner.generatePlan(from: image, locale: locale)
            // Merge due dates from composed tasks into enriched plan when ids match
            let mapped = mergePlan(enriched, with: tasks)
            tasks = mapped
        } catch {
            print("OpenAI enrichment failed: \(error)")
        }
        
        return Plan(project: "TatsuTori Photo Split", locale: locale, tasks: tasks).validated()
    }
    
    private func mergePlan(_ remotePlan: Plan, with scheduledTasks: [TidyTask]) -> [TidyTask] {
        var remaining = scheduledTasks
        var merged: [TidyTask] = []
        for remote in remotePlan.tasks {
            guard let labelKey = remote.labels?.first,
                  let index = remaining.firstIndex(where: { $0.labels?.first == labelKey }) else {
                continue
            }
            let scheduled = remaining.remove(at: index)
            let mergedTask = TidyTask(
                id: remote.id,
                title: remote.title,
                area: remote.area,
                exit_tag: remote.exit_tag ?? scheduled.exitTag,
                priority: remote.priority ?? scheduled.priority,
                effort_min: remote.effort_min ?? scheduled.effortMinutes,
                labels: remote.labels ?? scheduled.labels,
                checklist: remote.checklist ?? scheduled.checklist,
                links: remote.links ?? scheduled.links,
                url: remote.url,
                due_at: scheduled.due_at
            )
            merged.append(mergedTask)
        }
        merged.append(contentsOf: remaining)
        return merged.isEmpty ? scheduledTasks : merged
    }
    
    static func fallbackPlan() -> Plan {
        return FallbackPlanner.generatePlan()
    }
}
