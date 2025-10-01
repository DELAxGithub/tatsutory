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
