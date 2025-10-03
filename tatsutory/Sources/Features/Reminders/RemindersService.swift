import Foundation
import EventKit
import Photos

class RemindersService {
    private let eventStore = EKEventStore()
    private let galleryService = PhotoGalleryService()
    
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
            throw TatsuToriError.reminderSaveFailed(NSError(domain: "RemindersService", code: 1, userInfo: [NSLocalizedDescriptionKey: L10n.string("reminders.error.no_default_calendar")]))
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
        guard !tasks.isEmpty else { return 0 }

        var importedCount = 0
        do {
            for task in tasks {
                let reminder = try await buildReminder(from: task, calendar: calendar)
                try eventStore.save(reminder, commit: false)
                importedCount += 1
            }
            try eventStore.commit()
            return importedCount
        } catch {
            eventStore.reset()
            throw error
        }
    }

    private func buildReminder(from task: TidyTask, calendar: EKCalendar) async throws -> EKReminder {
        let reminder = EKReminder(eventStore: eventStore)
        reminder.calendar = calendar
        reminder.title = sanitizeTitle(task.title)
        reminder.notes = composeNotes(primary: task.note, checklist: task.checklist, links: task.links, tips: task.tips)

        if let dueDate = task.dueDate {
            reminder.dueDateComponents = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: dueDate)
        }

        reminder.url = firstValidURL(from: task.links)

        // TODO: Add tags when EKReminder.tags API becomes available
        // Note: tags API requires iOS 15+ but seems to have compilation issues
        // For now, we add tag information to notes instead
        var tagInfo: [String] = []
        if let exitTag = task.exit_tag {
            tagInfo.append("#\(exitTag.rawValue)")
        }
        if let category = task.category {
            tagInfo.append("#\(category)")
        }
        tagInfo.append("#TatsuTori")

        if !tagInfo.isEmpty {
            let tagString = tagInfo.joined(separator: " ")
            if let notes = reminder.notes {
                reminder.notes = notes + "\n\n" + tagString
            } else {
                reminder.notes = tagString
            }
        }

        // Note: EKReminder doesn't support direct photo attachments
        // Photo is saved in gallery and can be accessed via Photos app
        // We store the asset ID in notes for reference if needed
        if let photoAssetID = task.photoAssetID {
            if var notes = reminder.notes {
                notes += "\n\n📷 Photo ID: \(photoAssetID)"
                reminder.notes = notes
            } else {
                reminder.notes = "📷 Photo ID: \(photoAssetID)"
            }
        }

        return reminder
    }

    private func sanitizeTitle(_ title: String) -> String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return L10n.string("reminders.default_title") }
        return String(trimmed.prefix(120))
    }

    private func composeNotes(primary: String?, checklist: [String]?, links: [String]?, tips: String?) -> String? {
        var sections: [String] = []

        // Main note
        if let main = sanitizeLine(primary) {
            sections.append(main)
        }

        // Tips section
        if let tipsText = sanitizeLine(tips) {
            sections.append("💡 " + tipsText)
        }

        // Checklist
        let checklistItems = sanitizeList(checklist)
        if !checklistItems.isEmpty {
            let lines = [L10n.string("reminders.section.checklist")] + checklistItems.map { "- \($0)" }
            sections.append(lines.joined(separator: "\n"))
        }

        // Links
        let linkItems = sanitizeList(links)
        if !linkItems.isEmpty {
            let lines = [L10n.string("reminders.section.links")] + linkItems.map { "- \($0)" }
            sections.append(lines.joined(separator: "\n"))
        }

        guard !sections.isEmpty else { return nil }
        return sections.joined(separator: "\n\n")
    }

    private func sanitizeLine(_ value: String?) -> String? {
        guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else {
            return nil
        }
        return String(value.prefix(280))
    }

    private func sanitizeList(_ values: [String]?) -> [String] {
        guard let values = values else { return [] }
        var seen = Set<String>()
        var result: [String] = []
        for value in values {
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            if seen.insert(trimmed).inserted {
                result.append(String(trimmed.prefix(160)))
            }
        }
        return result
    }

    private func firstValidURL(from values: [String]?) -> URL? {
        for value in sanitizeList(values) {
            if let url = URL(string: value), url.scheme != nil {
                return url
            }
        }
        return nil
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
                  creationDate >= today && creationDate < tomorrow else {
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
