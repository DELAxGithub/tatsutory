import Foundation

struct WBSComposer {
    private let goalDate: Date
    
    init(goalDate: Date) {
        self.goalDate = goalDate
    }
    
    func schedule(for tag: ExitTag) -> TaskSchedule {
        let offset: Int
        switch tag {
        case .sell: offset = -7
        case .give: offset = -5
        case .recycle: offset = -3
        case .trash: offset = -2
        case .keep: offset = -1
        }
        let due = Calendar.current.date(byAdding: .day, value: offset, to: goalDate) ?? goalDate
        return TaskSchedule(exitTag: tag, dueDate: due, offsetDays: offset)
    }
}

