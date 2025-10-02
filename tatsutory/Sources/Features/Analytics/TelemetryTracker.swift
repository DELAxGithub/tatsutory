import Foundation

struct TelemetryEvent {
    let name: String
    let properties: [String: Any]
    let timestamp: Date
}

final class TelemetryTracker {
    static let shared = TelemetryTracker()
    private let queue = DispatchQueue(label: "telemetry.queue")
    private var events: [TelemetryEvent] = []
    
    private init() {}
    
    enum EnrichmentSkipReason: String {
        case consentOff = "consent_off"
        case networkDisallowed = "network_disallowed"
        case missingAPIKey = "missing_api_key"
        case noDetectedItems = "no_detected_items"
        case concurrencyBusy = "concurrency_busy"
    }

    private(set) var lastEnrichmentSkipReason: EnrichmentSkipReason?

    func trackDetection(duration: TimeInterval, itemCount: Int, usedFallback: Bool) {
        let props: [String: Any] = [
            "duration_ms": Int(duration * 1000),
            "item_count": itemCount,
            "fallback": usedFallback
        ]
        record(name: "detection", properties: props)
    }
    
    func trackExportResult(success: Bool, taskCount: Int, error: Error? = nil) {
        var props: [String: Any] = [
            "success": success,
            "task_count": taskCount
        ]
        if let error = error {
            props["error"] = error.localizedDescription
        }
        record(name: "export", properties: props)
    }
    
    func trackSelectionChange(taskId: String, enabled: Bool) {
        record(name: "preview_toggle", properties: [
            "task_id": taskId,
            "enabled": enabled
        ])
    }
    
    func trackClearAll() {
        record(name: "preview_clear_all", properties: [:])
    }
    
    func trackAIEnrichmentAttempt(id: String, attempt: Int) {
         record(name: "ai_enrichment_attempt", properties: [
            "id": id,
            "attempt": attempt
        ])
    }

    func trackAIEnrichmentResult(id: String, success: Bool, attempt: Int, requestId: String? = nil, status: Int? = nil) {
        var props: [String: Any] = [
            "id": id,
            "success": success,
            "attempt": attempt
        ]
        if let requestId = requestId { props["request_id"] = requestId }
        if let status = status { props["status"] = status }
        record(name: "ai_enrichment_result", properties: props)
    }

    func trackAIEnrichmentRateLimit(id: String, attempt: Int, retryAfter: TimeInterval?) {
        var props: [String: Any] = [
            "id": id,
            "attempt": attempt
        ]
        if let retryAfter = retryAfter { props["retry_after_s"] = retryAfter }
        record(name: "ai_enrichment_rate_limit", properties: props)
    }

    func trackAIEnrichmentSkip(reason: EnrichmentSkipReason) {
        lastEnrichmentSkipReason = reason
        record(name: "ai_enrichment_skip", properties: [
            "reason": reason.rawValue
        ])
    }

    func trackFeatureFlagChange(name: String, enabled: Bool) {
        record(name: "feature_flag_changed", properties: [
            "flag": name,
            "enabled": enabled
        ])
    }

    func trackAISettingsSnapshot(featureEnabled: Bool, consent: Bool, hasAPIKey: Bool, allowNetwork: Bool) {
        record(name: "ai_settings_snapshot", properties: [
            "feature_enabled": featureEnabled,
            "consent": consent,
            "has_api_key": hasAPIKey,
            "allow_network": allowNetwork
        ])
    }

    func localizedSkipReason() -> String {
        guard let reason = lastEnrichmentSkipReason else { return "-" }
        switch reason {
        case .consentOff: return L10n.string("telemetry.skip.consent_off")
        case .networkDisallowed: return L10n.string("telemetry.skip.network")
        case .missingAPIKey: return L10n.string("telemetry.skip.api_key")
        case .noDetectedItems: return L10n.string("telemetry.skip.no_items")
        case .concurrencyBusy: return L10n.string("telemetry.skip.concurrency")
        }
    }

    func latestSkipReasonLabel() -> String {
        localizedSkipReason()
    }

    func trackDetectionRaw(route: String, count: Int) {
        record(name: "detection_raw_count", properties: [
            "route": route,
            "count": count
        ])
    }

    func trackDetectionNormalized(route: String, count: Int, dropped: Int) {
        record(name: "detection_normalized_count", properties: [
            "route": route,
            "count": count,
            "dropped": dropped
        ])
    }

    func trackDetectionAfterThreshold(route: String, count: Int) {
        record(name: "detection_after_threshold_count", properties: [
            "route": route,
            "count": count
        ])
    }

    func event(_ name: String, _ props: [String: String] = [:]) {
        record(name: name, properties: props)
    }
    
    func flushIfNeeded() {
        queue.async {
            guard !self.events.isEmpty else { return }
            #if DEBUG
            for event in self.events {
                print("[Telemetry] \(event.name): \(event.properties)")
            }
            #endif
            self.events.removeAll()
        }
    }
    
    private func record(name: String, properties: [String: Any]) {
        let event = TelemetryEvent(name: name, properties: properties, timestamp: Date())
        queue.async {
            self.events.append(event)
        }
    }
}
