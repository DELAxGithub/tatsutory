import Foundation
import Combine
import Security

// MARK: - Feature Flags

struct FeatureFlags {
    private static let overrides = FeatureFlagOverrides.shared

    static var intentSettingsV1: Bool {
        get { overrides.intentSettingsV1 }
        set { overrides.intentSettingsV1 = newValue }
    }

    #if DEBUG
    static let photoMultiSplit = true
    static let usePhotoLibraryFallback = false
    #else
    static let photoMultiSplit = false
    static let usePhotoLibraryFallback = false
    #endif
}

// MARK: - Models

enum Purpose: String, Codable, CaseIterable {
    case move_fast
    case move_value
    case cleanup
    case legacy_hidden
}

enum SmallThreshold: String, Codable, CaseIterable {
    case low
    case `default`
    case high
}

extension SmallThreshold {
    var localizationKey: String {
        switch self {
        case .low: return "settings.advanced.small_threshold.low"
        case .default: return "settings.advanced.small_threshold.default"
        case .high: return "settings.advanced.small_threshold.high"
        }
    }
}

struct LLMConfig: Codable {
    var consent: Bool
    var timeoutSec: Int
    var concurrency: Int
}

struct IntentSettings: Codable {
    var purpose: Purpose
    var goalDateISO: String
    var region: String
    var remindersList: String
    var smallItemThreshold: SmallThreshold
    var maxTasksPerPhoto: Int
    var offsets: [String: Int]
    var llm: LLMConfig
}

// MARK: - Store

final class IntentSettingsStore: ObservableObject {
    static let shared = IntentSettingsStore()

    @Published private(set) var value: IntentSettings

    private let defaults = UserDefaults.standard
    private let settingsKey = "intent.settings.v1"
    private let consentKey = "intent.llm.consent"

    private init() {
        let consent = KeychainHelper.readBool(forKey: consentKey) ?? false
        self.value = IntentSettingsStore.load(defaults: defaults, consent: consent)
    }

    func update(_ edit: (inout IntentSettings) -> Void) {
        var next = value
        let previous = value
        edit(&next)
        value = next
        save(next)

        if previous.purpose != next.purpose {
            TelemetryTracker.shared.event("intent_changed", ["old": previous.purpose.rawValue, "new": next.purpose.rawValue])
            if previous.purpose != .legacy_hidden && next.purpose == .legacy_hidden {
                TelemetryTracker.shared.event("legacy_mode_enabled")
            }
        }

        if previous.llm.consent != next.llm.consent {
            KeychainHelper.writeBool(next.llm.consent, forKey: consentKey)
        }
    }

    private func save(_ settings: IntentSettings) {
        var payload = settings
        // persist consent separately via Keychain; ensure stored copy mirrors latest consent for defaults snapshot
        if let data = try? JSONEncoder().encode(payload) {
            defaults.set(data, forKey: settingsKey)
        }
    }

    private static func load(defaults: UserDefaults, consent: Bool) -> IntentSettings {
        if let data = defaults.data(forKey: "intent.settings.v1"),
           var stored = try? JSONDecoder().decode(IntentSettings.self, from: data) {
            stored.llm.consent = consent
            return stored
        }
        let formatter = ISO8601DateFormatter()
        let defaultDate = formatter.string(from: Date().addingTimeInterval(14 * 86_400))
        return IntentSettings(
            purpose: .move_fast,
            goalDateISO: defaultDate,
            region: "JP",
            remindersList: "TatsuTori",
            smallItemThreshold: .default,
            maxTasksPerPhoto: 8,
            offsets: [
                "SELL": -7,
                "GIVE": -5,
                "RECYCLE": -3,
                "TRASH": -2,
                "KEEP": -1
            ],
            llm: LLMConfig(consent: consent, timeoutSec: 8, concurrency: 1)
        )
    }
}

// MARK: - Keychain Helper

enum KeychainHelper {
    static func writeBool(_ value: Bool, forKey key: String) {
        let data = Data([value ? 1 : 0])
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: key,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(query as CFDictionary)
        var insert = query
        insert[kSecValueData as String] = data
        SecItemAdd(insert as CFDictionary, nil)
    }

    static func readBool(forKey key: String) -> Bool? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: key,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data, let byte = data.first else {
            return nil
        }
        return byte != 0
    }
}

// MARK: - Legacy Consent Store (camera toggle compatibility)

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
