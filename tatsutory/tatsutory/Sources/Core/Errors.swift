import Foundation

enum TatsuToriError: LocalizedError {
    case noAPIKey
    case cameraUnavailable
    case remindersAccessDenied
    case networkError(Error)
    case invalidJSON
    case planningFailed
    case reminderSaveFailed(Error)
    
    var errorDescription: String? {
        switch self {
        case .noAPIKey:
            return "API key not configured. Please add your OpenAI API key in Settings."
        case .cameraUnavailable:
            return "Camera is not available on this device."
        case .remindersAccessDenied:
            return "Reminders access denied. Please allow access in Settings app."
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .invalidJSON:
            return "Invalid JSON format received from AI service."
        case .planningFailed:
            return "AI planning failed. Using fallback plan."
        case .reminderSaveFailed(let error):
            return "Failed to save reminders: \(error.localizedDescription)"
        }
    }
}