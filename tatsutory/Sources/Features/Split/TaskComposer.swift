import Foundation

/// Minimal fallback task generator - only used when LLM fails
struct TaskComposer {
    private static let isoFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    /// Create a single fallback task when all else fails
    static func fallbackTask(settings: IntentSettings, locale: UserLocale, itemCount: Int = 0) -> TidyTask {
        let goalDate = isoFormatter.date(from: settings.goalDateISO) ?? Date()
        let fallbackDate = Calendar.current.date(byAdding: .day, value: -3, to: goalDate) ?? goalDate

        let systemLanguage = Locale.preferredLanguages.first ?? "en"
        let isJapanese = locale.country.uppercased() == "JP" || systemLanguage.hasPrefix("ja")

        let title: String
        let checklist: [String]

        if isJapanese {
            title = itemCount > 0 ? "\(itemCount)個のアイテムを整理する" : "検出されたアイテムを整理する"
            checklist = [
                "写真の中のアイテムを確認する",
                "各アイテムの処分方法を決める",
                "必要に応じて手動でタスクを作成する"
            ]
        } else {
            title = itemCount > 0 ? "Review \(itemCount) detected items" : "Review detected items"
            checklist = [
                "Check items in the photo",
                "Decide disposal method for each",
                "Create tasks manually if needed"
            ]
        }

        return TidyTask(
            id: UUID().uuidString,
            title: title,
            category: nil,
            note: nil,
            tips: nil,
            area: nil,
            exit_tag: .keep,
            priority: 3,
            effort_min: 15,
            labels: ["fallback"],
            checklist: checklist,
            links: [],
            url: nil,
            due_at: isoFormatter.string(from: fallbackDate)
        )
    }

    /// Create fallback plan when LLM completely fails
    static func fallbackPlan(settings: IntentSettings, locale: UserLocale, itemCount: Int = 0) -> Plan {
        let task = fallbackTask(settings: settings, locale: locale, itemCount: itemCount)

        let systemLanguage = Locale.preferredLanguages.first ?? "en"
        let isJapanese = locale.country.uppercased() == "JP" || systemLanguage.hasPrefix("ja")
        let projectName = isJapanese ? "片付けプロジェクト" : "Declutter Project"

        return Plan(project: projectName, locale: locale, tasks: [task]).validated()
    }
}
