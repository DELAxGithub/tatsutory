import Foundation

enum TatsuToriError: LocalizedError {
    case noAPIKey
    case cameraUnavailable
    case remindersAccessDenied
    case networkError(Error)
    case rateLimited(retryAfter: TimeInterval?)
    case invalidJSON
    case planningFailed
    case reminderSaveFailed(Error)
    
    var errorDescription: String? {
        switch self {
        case .noAPIKey:
            return L10n.string("errors.no_api_key")
        case .cameraUnavailable:
            return L10n.string("errors.camera_unavailable")
        case .remindersAccessDenied:
            return L10n.string("errors.reminders_denied")
        case .networkError(let error):
            return L10n.string("errors.network", error.localizedDescription)
        case .rateLimited(let retryAfter):
            if let retryAfter {
                return L10n.string("errors.rate_limited_retry", Int(retryAfter))
            }
            return L10n.string("errors.rate_limited")
        case .invalidJSON:
            return L10n.string("errors.invalid_json")
        case .planningFailed:
            return L10n.string("errors.planning_failed")
        case .reminderSaveFailed(let error):
            return L10n.string("errors.reminder_save_failed", error.localizedDescription)
        }
    }
}
