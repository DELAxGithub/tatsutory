import UIKit

final class PhotoSplitService {
    private let maxItems: Int
    private static let rateLimiter = RemoteDetectionRateLimiter()

    init(maxItems: Int = 8) {
        self.maxItems = maxItems
    }

    func detectItems(in image: UIImage, settings: IntentSettings, allowNetwork: Bool) async -> PhotoSplitResult {
        if let remaining = await Self.rateLimiter.remainingWaitInterval() {
            TelemetryTracker.shared.event("detector_remote_status", [
                "status": "429_cached",
                "remaining_s": "\(Int(ceil(remaining)))"
            ])
            TelemetryTracker.shared.event("detector_route", ["route": "local_fallback"])
            let message = "AI検出がレート制限中です。約\(Int(ceil(remaining)))秒後に再試行してください。"
            return PhotoSplitResult(items: [], processingTime: 0, usedFallback: true, errorMessage: message)
        }

        guard allowNetwork, settings.llm.consent else {
            TelemetryTracker.shared.event("detector_route", ["route": "local_fallback"])
            return PhotoSplitResult(
                items: [],
                processingTime: 0,
                usedFallback: true,
                errorMessage: "AI検出がオフのため、ローカルプランを表示しています。"
            )
        }
        let apiKey = Secrets.load()
        guard !apiKey.isEmpty else {
            TelemetryTracker.shared.trackAIEnrichmentSkip(reason: .missingAPIKey)
            TelemetryTracker.shared.event("detector_route", ["route": "local_fallback"])
            return PhotoSplitResult(
                items: [],
                processingTime: 0,
                usedFallback: true,
                errorMessage: "OpenAI APIキーが設定されていないため、ローカルプランのみ表示します。"
            )
        }
        let service = RemoteDetectionService(apiKey: apiKey)
        do {
            let start = Date()
            let detected = try await service.detect(from: image, settings: settings)
            let limited = Array(detected.prefix(maxItems))
            let duration = Date().timeIntervalSince(start)
            TelemetryTracker.shared.event("detector_route", ["route": "remote"])
            TelemetryTracker.shared.trackDetectionAfterThreshold(route: "remote", count: limited.count)
            return PhotoSplitResult(items: limited, processingTime: duration, usedFallback: limited.isEmpty, errorMessage: nil)
        } catch {
            TelemetryTracker.shared.event("detector_remote_status", ["error": error.localizedDescription])
            TelemetryTracker.shared.event("detector_route", ["route": "local_fallback"])
            let message: String
            if case let TatsuToriError.rateLimited(retryAfter) = error {
                await Self.rateLimiter.registerRetryAfter(retryAfter)
                let wait = Int(ceil((retryAfter ?? 10)))
                message = "AI検出がレート制限に達しました。約\(wait)秒後に再試行してください。"
            } else if let tatsuError = error as? TatsuToriError {
                message = tatsuError.errorDescription ?? "遠隔検出に失敗しました。"
            } else {
                message = error.localizedDescription
            }
            return PhotoSplitResult(items: [], processingTime: 0, usedFallback: true, errorMessage: message)
        }
    }
}

private actor RemoteDetectionRateLimiter {
    private var nextAllowed: Date?

    func remainingWaitInterval() -> TimeInterval? {
        guard let next = nextAllowed else { return nil }
        let interval = next.timeIntervalSinceNow
        return interval > 0 ? interval : nil
    }

    func registerRetryAfter(_ retryAfter: TimeInterval?) {
        let wait = max(retryAfter ?? 10, 5)
        nextAllowed = Date().addingTimeInterval(wait)
    }
}
