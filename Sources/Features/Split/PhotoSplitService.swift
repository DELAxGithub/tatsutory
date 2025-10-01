import CoreML
import UIKit
import Vision

// MARK: - Photo Split Service

final class PhotoSplitService {
    private let maxItems: Int
    private let consentStore: ConsentStore
    private let sessionQueue = DispatchQueue(label: "photo.split.service")
    
    init(maxItems: Int = 8, consentStore: ConsentStore = .shared) {
        self.maxItems = maxItems
        self.consentStore = consentStore
    }
    
    func detectItems(in image: UIImage) async -> PhotoSplitResult {
        let start = Date()
        guard let cgImage = image.cgImage else {
            return PhotoSplitResult(items: [], processingTime: 0, usedFallback: true)
        }
        
        let requestHandler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        let request = VNRecognizeObjectsRequest()
        request.usesCPUOnly = false
        request.maximumResults = maxItems
        request.imageCropAndScaleOption = .centerCrop
        
        do {
            let observations: [VNRecognizedObjectObservation] = try await withCheckedThrowingContinuation { continuation in
                sessionQueue.async {
                    do {
                        try requestHandler.perform([request])
                        let results = request.results as? [VNRecognizedObjectObservation] ?? []
                        continuation.resume(returning: results)
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
            }
            let size = CGSize(width: cgImage.width, height: cgImage.height)
            let detected = observations
                .sorted { $0.confidence > $1.confidence }
                .prefix(maxItems)
                .enumerated()
                .compactMap { index, observation -> DetectedItem? in
                    guard let label = observation.labels.first?.identifier else { return nil }
                    let rect = observation.boundingBox.denormalized(to: size)
                    return DetectedItem(id: UUID(), label: label, confidence: Double(observation.confidence), boundingBox: rect, imageSize: size)
                }
            let elapsed = Date().timeIntervalSince(start)
            return PhotoSplitResult(items: Array(detected), processingTime: elapsed, usedFallback: false)
        } catch {
            let elapsed = Date().timeIntervalSince(start)
            return PhotoSplitResult(items: [], processingTime: elapsed, usedFallback: true)
        }
    }
}

private extension CGRect {
    func denormalized(to size: CGSize) -> CGRect {
        return CGRect(
            x: origin.x * size.width,
            y: (1 - origin.y - height) * size.height,
            width: width * size.width,
            height: height * size.height
        )
    }
}

