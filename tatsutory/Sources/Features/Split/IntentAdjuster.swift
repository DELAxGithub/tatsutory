import CoreGraphics
import Foundation

struct IntentAdjuster {
    static func filter(items: [DetectedItem], settings: IntentSettings) -> [DetectedItem] {
        guard !items.isEmpty else { return [] }

        let base: CGFloat = 0.025
        let multiplier: CGFloat
        switch settings.smallItemThreshold {
        case .low: multiplier = 0.6
        case .default: multiplier = 1.0
        case .high: multiplier = 1.4
        }
        let threshold = base * multiplier

        var filtered = items.filter { $0.areaRatio >= threshold }
        if filtered.isEmpty, let largest = items.max(by: { $0.areaRatio < $1.areaRatio }) {
            filtered = [largest]
        }
        return Array(filtered.prefix(settings.maxTasksPerPhoto))
    }
}
