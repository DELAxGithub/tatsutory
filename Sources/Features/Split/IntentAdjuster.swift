import CoreGraphics
import Foundation

struct IntentAdjuster {
    private let intent: UserIntent
    private let smallItemThreshold: CGFloat = 0.025 // 2.5% of frame
    
    init(intent: UserIntent) {
        self.intent = intent
    }
    
    func filter(items: [DetectedItem]) -> [DetectedItem] {
        let filtered = items.filter { item in
            switch intent.bias {
            case .sellFirst:
                return item.areaRatio >= smallItemThreshold * 0.8
            case .fastDispose:
                return item.areaRatio >= smallItemThreshold
            case .keepMore:
                return true
            }
        }
        return Array(filtered.prefix(8))
    }
}
