import Foundation

// MARK: - Core Models

struct UserLocale: Codable {
    let country: String
    let city: String
}

enum ExitTag: String, CaseIterable, Codable {
    case sell = "SELL"
    case give = "GIVE"
    case recycle = "RECYCLE"
    case trash = "TRASH"
    case keep = "KEEP"
    
    var displayName: String {
        switch self {
        case .sell: return "Sell"
        case .give: return "Give"
        case .recycle: return "Recycle"
        case .trash: return "Trash"
        case .keep: return "Keep"
        }
    }
    
    var systemImage: String {
        switch self {
        case .sell: return "dollarsign.circle"
        case .give: return "heart.circle"
        case .recycle: return "arrow.3.trianglepath"
        case .trash: return "trash.circle"
        case .keep: return "archivebox.circle"
        }
    }
}

struct TidyTask: Codable, Identifiable {
    let id: String
    let title: String
    let category: String?
    let note: String?
    let tips: String?
    let area: String?
    let exit_tag: ExitTag?
    let priority: Int?
    let effort_min: Int?
    let labels: [String]?
    let checklist: [String]?
    let links: [String]?
    let url: String?
    let due_at: String? // ISO8601
    let photoAssetID: String? // PHAsset identifier for photo attachment

    // Computed properties
    var exitTag: ExitTag {
        return exit_tag ?? .keep
    }
    
    var effortMinutes: Int {
        return effort_min ?? 15
    }
    
    var taskPriority: Int {
        return priority ?? 3
    }
    
    var isHighPriority: Bool {
        return taskPriority >= 4
    }
    
    var dueDate: Date? {
        guard let due_at = due_at else { return nil }
        return ISO8601DateFormatter().date(from: due_at)
    }
}

struct Plan: Codable {
    let project: String
    let locale: UserLocale
    let tasks: [TidyTask]
}

// MARK: - Validation Extensions

extension TidyTask {
    var isValid: Bool {
        return !id.isEmpty && !title.isEmpty
    }
    
    static func validate(_ tasks: [TidyTask]) -> [TidyTask] {
        return tasks.filter { $0.isValid }
    }
}

extension Plan {
    func validated() -> Plan {
        return Plan(
            project: project,
            locale: locale,
            tasks: TidyTask.validate(tasks)
        )
    }
}

// MARK: - Overview Plan Models

/// 初手モード（Overview Mode）のレスポンス構造
struct OverviewPlan: Codable {
    let overview: Overview
    let priorityAreas: [PriorityArea]
    let quickStart: String

    enum CodingKeys: String, CodingKey {
        case overview
        case priorityAreas = "priority_areas"
        case quickStart = "quick_start"
    }

    struct Overview: Codable {
        let state: String          // 状態: 物の総量と処分対象の見積もり
        let estimatedTime: String  // 推定時間: 仕分け・処分手配の総時間
        let mainIssues: [String]   // 主な課題

        enum CodingKeys: String, CodingKey {
            case state = "状態"
            case estimatedTime = "推定時間"
            case mainIssues = "主な課題"
        }
    }

    struct PriorityArea: Codable, Identifiable {
        let rank: Int              // 順位
        let areaName: String       // エリア名
        let reason: String         // 理由
        let tasks: [String]        // 作業内容
        let timeRequired: String   // 所要時間
        let difficulty: Difficulty // 難易度
        let impact: Impact         // 効果

        var id: Int { rank }

        enum CodingKeys: String, CodingKey {
            case rank = "順位"
            case areaName = "エリア名"
            case reason = "理由"
            case tasks = "作業内容"
            case timeRequired = "所要時間"
            case difficulty = "難易度"
            case impact = "効果"
        }

        enum Difficulty: String, Codable {
            case easy = "簡単"
            case normal = "普通"
            case hard = "難しい"

            var displayText: String {
                switch self {
                case .easy: return "簡単"
                case .normal: return "普通"
                case .hard: return "難しい"
                }
            }
        }

        enum Impact: String, Codable {
            case high = "大"
            case medium = "中"
            case low = "小"

            var displayText: String {
                switch self {
                case .high: return "大"
                case .medium: return "中"
                case .low: return "小"
                }
            }
        }
    }
}
