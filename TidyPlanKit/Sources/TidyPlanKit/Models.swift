import Foundation

// MARK: - Core Models

public struct UserLocale: Codable {
    public let country: String
    public let city: String
    
    public init(country: String, city: String) {
        self.country = country
        self.city = city
    }
}

public enum ExitTag: String, CaseIterable, Codable {
    case sell = "SELL"
    case give = "GIVE"
    case recycle = "RECYCLE"
    case trash = "TRASH"
    case keep = "KEEP"
    
    public var displayName: String {
        switch self {
        case .sell: return "Sell"
        case .give: return "Give"
        case .recycle: return "Recycle"
        case .trash: return "Trash"
        case .keep: return "Keep"
        }
    }
    
    public var systemImage: String {
        switch self {
        case .sell: return "dollarsign.circle"
        case .give: return "heart.circle"
        case .recycle: return "arrow.3.trianglepath"
        case .trash: return "trash.circle"
        case .keep: return "archivebox.circle"
        }
    }
}

public struct TidyTask: Codable, Identifiable {
    public let id: String
    public let title: String
    public let area: String?
    public let exit_tag: ExitTag?
    public let priority: Int?
    public let effort_min: Int?
    public let labels: [String]?
    public let checklist: [String]?
    public let links: [String]?
    public let url: String?
    public let due_at: String? // ISO8601
    
    public init(id: String, title: String, area: String?, exit_tag: ExitTag?, priority: Int?, effort_min: Int?, labels: [String]?, checklist: [String]?, links: [String]?, url: String?, due_at: String?) {
        self.id = id
        self.title = title
        self.area = area
        self.exit_tag = exit_tag
        self.priority = priority
        self.effort_min = effort_min
        self.labels = labels
        self.checklist = checklist
        self.links = links
        self.url = url
        self.due_at = due_at
    }
    
    // Computed properties
    public var exitTag: ExitTag { exit_tag ?? .keep }
    public var effortMinutes: Int { effort_min ?? 15 }
    public var taskPriority: Int { priority ?? 3 }
    public var isHighPriority: Bool { taskPriority >= 4 }
    public var dueDate: Date? {
        guard let due_at = due_at else { return nil }
        return ISO8601DateFormatter().date(from: due_at)
    }
}

public struct Plan: Codable {
    public let project: String
    public let locale: UserLocale
    public let tasks: [TidyTask]
    
    public init(project: String, locale: UserLocale, tasks: [TidyTask]) {
        self.project = project
        self.locale = locale
        self.tasks = tasks
    }
}

// MARK: - Validation Extensions

public extension TidyTask {
    var isValid: Bool { !id.isEmpty && !title.isEmpty }
    static func validate(_ tasks: [TidyTask]) -> [TidyTask] { tasks.filter { $0.isValid } }
}

public extension Plan {
    func validated() -> Plan {
        Plan(project: project, locale: locale, tasks: TidyTask.validate(tasks))
    }
}

