import Foundation

struct WBSComposer {
    private let goalDate: Date
    private let offsets: [String: Int]
    
    init(goalDate: Date, offsets: [String: Int]) {
        self.goalDate = goalDate
        self.offsets = offsets
    }
    
    func schedule(for tag: ExitTag) -> TaskSchedule {
        let offset = offsets[tag.rawValue] ?? defaultOffset(for: tag)
        let due = Calendar.current.date(byAdding: .day, value: offset, to: goalDate) ?? goalDate
        return TaskSchedule(exitTag: tag, dueDate: due, offsetDays: offset)
    }
    
    private func defaultOffset(for tag: ExitTag) -> Int {
        switch tag {
        case .sell: return -7
        case .give: return -5
        case .recycle: return -3
        case .trash: return -2
        case .keep: return -1
        }
    }
}
