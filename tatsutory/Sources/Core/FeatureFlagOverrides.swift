import Foundation

final class FeatureFlagOverrides {
    static let shared = FeatureFlagOverrides()

    private let defaults: UserDefaults
    private let intentSettingsKey = "feature.intentSettingsV1"

    private init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        defaults.register(defaults: [intentSettingsKey: true])
    }

    var intentSettingsV1: Bool {
        get { defaults.bool(forKey: intentSettingsKey) }
        set {
            let previous = defaults.bool(forKey: intentSettingsKey)
            guard previous != newValue else { return }
            defaults.set(newValue, forKey: intentSettingsKey)
            TelemetryTracker.shared.trackFeatureFlagChange(name: "intentSettingsV1", enabled: newValue)
        }
    }
}
