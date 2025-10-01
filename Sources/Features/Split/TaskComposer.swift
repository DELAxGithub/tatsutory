import Foundation

struct TaskComposer {
    private let locale: UserLocale
    private let intent: UserIntent
    private let goalDate: Date
    private let scheduler: WBSComposer
    
    init(locale: UserLocale, intent: UserIntent, goalDate: Date) {
        self.locale = locale
        self.intent = intent
        self.goalDate = goalDate
        self.scheduler = WBSComposer(goalDate: goalDate)
    }
    
    func buildTasks(from items: [DetectedItem]) -> [TidyTask] {
        guard !items.isEmpty else { return fallbackTask() }
        return items.map { item in
            let exitTag = inferExitTag(for: item)
            let schedule = scheduler.schedule(for: exitTag)
            let dueString = ISO8601DateFormatter().string(from: schedule.dueDate)
            let checklist = LocaleGuide.getTemplateChecklist(for: exitTag, locale: locale)
            let links = LocaleGuide.getDefaultLinks(for: locale, exitTag: exitTag)
            let title = "\(exitTag.rawValue): \(item.label.capitalized)"
            let notes = buildNotes(for: item, tag: exitTag, schedule: schedule)
            return TidyTask(
                id: item.id.uuidString,
                title: title,
                area: nil,
                exit_tag: exitTag,
                priority: inferPriority(for: item, exitTag: exitTag),
                effort_min: estimateEffort(for: item, exitTag: exitTag),
                labels: [item.label.lowercased()],
                checklist: checklist,
                links: links,
                url: nil,
                due_at: dueString
            )
        }
    }
    
    private func buildNotes(for item: DetectedItem, tag: ExitTag, schedule: TaskSchedule) -> [String] {
        let due = DateFormatter.localizedString(from: schedule.dueDate, dateStyle: .medium, timeStyle: .none)
        let confidenceLine = String(format: "Confidence %.0f%%", item.confidence * 100)
        return [
            "Detected item: \(item.label)",
            "Recommended exit: \(tag.displayName)",
            "Due by: \(due)",
            confidenceLine
        ]
    }
    
    private func fallbackTask() -> [TidyTask] {
        let due = scheduler.schedule(for: .recycle).dueDate
        let dueString = ISO8601DateFormatter().string(from: due)
        return [TidyTask(
            id: UUID().uuidString,
            title: "General decluttering task",
            area: nil,
            exit_tag: .keep,
            priority: 2,
            effort_min: 20,
            labels: ["general"],
            checklist: ["Sort items in photo", "Decide on exit plan"],
            links: [],
            url: nil,
            due_at: dueString
        )]
    }
    
    private func inferExitTag(for item: DetectedItem) -> ExitTag {
        let label = item.label.lowercased()
        if intent.bias == .sellFirst {
            if label.contains("box") || label.contains("trash") {
                return .trash
            }
            return .sell
        }
        if intent.bias == .keepMore {
            if label.contains("document") || label.contains("photo") {
                return .keep
            }
        }
        if label.contains("cardboard") || label.contains("box") {
            return .recycle
        }
        if label.contains("bag") || label.contains("clothes") {
            return intent.bias == .fastDispose ? .give : .sell
        }
        if label.contains("cable") || label.contains("electronics") {
            return .recycle
        }
        return intent.bias == .fastDispose ? .trash : .sell
    }
    
    private func inferPriority(for item: DetectedItem, exitTag: ExitTag) -> Int {
        switch exitTag {
        case .sell: return intent.bias == .sellFirst ? 4 : 3
        case .trash: return 4
        case .recycle: return 3
        case .give: return 2
        case .keep: return 1
        }
    }
    
    private func estimateEffort(for item: DetectedItem, exitTag: ExitTag) -> Int {
        switch exitTag {
        case .sell: return 45
        case .recycle: return 30
        case .trash: return 15
        case .give: return 25
        case .keep: return 10
        }
    }
}
