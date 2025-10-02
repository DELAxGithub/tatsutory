import CoreGraphics
import Foundation

struct DetectedItem: Identifiable, Codable {
    let id: UUID
    let label: String
    let confidence: Double
    let boundingBox: CGRect
    let areaRatio: CGFloat
    
    init(id: UUID = UUID(), label: String, confidence: Double, boundingBox: CGRect, imageSize: CGSize) {
        self.id = id
        self.label = label
        self.confidence = confidence
        self.boundingBox = boundingBox
        let imageArea = imageSize.width * imageSize.height
        if imageArea <= 0 {
            self.areaRatio = 0
        } else {
            let boxArea = boundingBox.width * boundingBox.height
            self.areaRatio = CGFloat(boxArea / imageArea)
        }
    }
}

struct AdjustedItem: Identifiable {
    let id: UUID
    let label: String
    let confidence: Double
    let boundingBox: CGRect
    let exitTag: ExitTag
    let dueDate: Date
    let checklist: [String]
    let notes: [String]
}

struct PhotoSplitResult {
    let items: [DetectedItem]
    let processingTime: TimeInterval
    let usedFallback: Bool
    let errorMessage: String?
}

struct TaskSchedule {
    let exitTag: ExitTag
    let dueDate: Date
    let offsetDays: Int
}
