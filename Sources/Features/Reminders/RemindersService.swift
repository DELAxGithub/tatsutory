import Foundation
import EventKit

class RemindersService {
    private let eventStore = EKEventStore()
    private let batchSize = 50
    
    func requestAccess() async throws {
        if #available(iOS 17, *) {
            try await eventStore.requestFullAccessToReminders()
        } else {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                eventStore.requestAccess(to: .reminder) { granted, error in
                    if let error = error {
                        continuation.resume(throwing: error)
                    } else if granted {
                        continuation.resume()
                    } else {
                        continuation.resume(throwing: TatsuToriError.remindersAccessDenied)
                    }
                }
            }
        }
    }
    
    func ensureList(named listName: String) throws -> EKCalendar {
        // Check if list already exists
        if let existingCalendar = eventStore.calendars(for: .reminder).first(where: { $0.title == listName }) {
            return existingCalendar
        }
        
        // Create new list
        guard let defaultCalendar = eventStore.defaultCalendarForNewReminders() else {
            throw TatsuToriError.reminderSaveFailed(NSError(domain: "RemindersService", code: 1, userInfo: [NSLocalizedDescriptionKey: "No default calendar available"]))
        }
        
        let newCalendar = EKCalendar(for: .reminder, eventStore: eventStore)
        newCalendar.title = listName
        newCalendar.source = defaultCalendar.source // Critical: use existing source
        
        try eventStore.saveCalendar(newCalendar, commit: true)
        return newCalendar
    }
    
    func importTasks(_ tasks: [TidyTask], into listName: String) async throws -> Int {
        try await requestAccess()
        
        let calendar = try ensureList(named: listName)
        var importedCount = 0
        
        // Process in batches
        let taskBatches = tasks.chunked(into: batchSize)
        
        for batch in taskBatches {
            for task in batch {
                try addTask(task, to: calendar)
                importedCount += 1
            }
            
            // Commit batch
            try eventStore.commit()
        }
        
        return importedCount
    }
    
    private func addTask(_ task: TidyTask, to calendar: EKCalendar) throws {
        let reminder = EKReminder(eventStore: eventStore)
        reminder.calendar = calendar
        reminder.title = "[\(task.id)] \(task.title)"
        
        // Build notes content
        var noteLines: [String] = []
        
        if let area = task.area {
            noteLines.append("📍 Area: \(area)")
        }
        
        noteLines.append("🏷️ Exit: \(task.exitTag.displayName)")
        
        if task.effortMinutes > 0 {
            noteLines.append("⏱️ Effort: \(task.effortMinutes) min")
        }
        
        if let labels = task.labels, !labels.isEmpty {
            noteLines.append("🏷️ Labels: \(labels.joined(separator: ", "))")
        }
        
        if let links = task.links, !links.isEmpty {
            noteLines.append("\n🔗 Links:")
            noteLines.append(contentsOf: links.map { "• \($0)" })
        }
        
        if let checklist = task.checklist, !checklist.isEmpty {
            noteLines.append("\n✅ Checklist:")
            noteLines.append(contentsOf: checklist.map { "• \($0)" })
        }
        
        reminder.notes = noteLines.joined(separator: "\n")
        
        // Set URL if available
        if let urlString = task.url, let url = URL(string: urlString) {
            reminder.url = url
        }
        
        // Set due date and alarm
        if let dueDate = task.dueDate {
            let calendar = Calendar.current
            reminder.dueDateComponents = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: dueDate)
            
            // Add alarm for high priority tasks
            if task.isHighPriority {
                reminder.addAlarm(EKAlarm(absoluteDate: dueDate))
            }
        }
        
        // Set priority (1=high, 9=low in EventKit)
        reminder.priority = task.isHighPriority ? 1 : 5
        
        try eventStore.save(reminder, commit: false) // Will commit in batch
    }
    
    func deleteTodaysReminders(from listName: String) async throws -> Int {
        try await requestAccess()
        
        guard let calendar = eventStore.calendars(for: .reminder).first(where: { $0.title == listName }) else {
            return 0
        }
        
        let today = Calendar.current.startOfDay(for: Date())
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today)!
        
        let predicate = eventStore.predicateForReminders(in: [calendar])
        let reminders = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[EKReminder], Error>) in
            eventStore.fetchReminders(matching: predicate) { reminders in
                if let reminders = reminders {
                    continuation.resume(returning: reminders)
                } else {
                    continuation.resume(returning: [])
                }
            }
        }
        
        // Filter to today's reminders with our format
        let todaysReminders = reminders.filter { reminder in
            guard let creationDate = reminder.creationDate,
                  creationDate >= today && creationDate < tomorrow,
                  let title = reminder.title,
                  title.contains("[") else {
                return false
            }
            return true
        }
        
        var deletedCount = 0
        for reminder in todaysReminders {
            try eventStore.remove(reminder, commit: false)
            deletedCount += 1
        }
        
        if deletedCount > 0 {
            try eventStore.commit()
        }
        
        return deletedCount
    }
}

// MARK: - Array Extension

extension Array {
    func chunked(into size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}