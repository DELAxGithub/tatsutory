import Foundation

// MARK: - Intent & Goal Settings

enum IntentContext: String, Codable, CaseIterable {
    case moving
    case downsizing
    case estate
    
    var displayName: String {
        switch self {
        case .moving: return "引っ越し"
        case .downsizing: return "断捨離"
        case .estate: return "終活"
        }
    }
}

enum DisposalBias: String, Codable, CaseIterable {
    case sellFirst
    case fastDispose
    case keepMore
    
    var displayName: String {
        switch self {
        case .sellFirst: return "売却優先"
        case .fastDispose: return "早く処分"
        case .keepMore: return "残す判断"
        }
    }
}

struct UserIntent: Codable {
    var context: IntentContext
    var bias: DisposalBias
    
    static let `default` = UserIntent(context: .moving, bias: .fastDispose)
}

final class IntentSettingsStore {
    static let shared = IntentSettingsStore()
    private let userDefaults: UserDefaults
    private let intentKey = "com.tatsutori.intent"
    private let goalKey = "com.tatsutori.goalDate"
    
    private init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }
    
    var currentIntent: UserIntent {
        get {
            guard let data = userDefaults.data(forKey: intentKey),
                  let intent = try? JSONDecoder().decode(UserIntent.self, from: data) else {
                return .default
            }
            return intent
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                userDefaults.set(data, forKey: intentKey)
            }
        }
    }
    
    var goalDate: Date {
        get {
            if let timestamp = userDefaults.object(forKey: goalKey) as? TimeInterval {
                return Date(timeIntervalSince1970: timestamp)
            }
            // Default to two weeks ahead when unset
            return Calendar.current.date(byAdding: .day, value: 14, to: Date()) ?? Date()
        }
        set {
            userDefaults.set(newValue.timeIntervalSince1970, forKey: goalKey)
        }
    }
}

// MARK: - Consent Settings

final class ConsentStore {
    static let shared = ConsentStore()
    private let userDefaults: UserDefaults
    private let consentKey = "com.tatsutori.visionConsent"
    private let promptKey = "com.tatsutori.visionConsent.prompted"
    
    private init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }
    
    var hasConsentedToVisionUpload: Bool {
        get { userDefaults.bool(forKey: consentKey) }
        set { userDefaults.set(newValue, forKey: consentKey) }
    }
    
    var hasCompletedPrompt: Bool {
        get { userDefaults.bool(forKey: promptKey) }
        set { userDefaults.set(newValue, forKey: promptKey) }
    }
}
