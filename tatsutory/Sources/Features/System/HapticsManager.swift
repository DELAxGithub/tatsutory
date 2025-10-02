import AVFoundation
import CoreHaptics
import UIKit

final class HapticsManager {
    static let shared = HapticsManager()
    private var engine: CHHapticEngine?
    private var supportsHaptics: Bool = CHHapticEngine.capabilitiesForHardware().supportsHaptics
    
    private init() {}
    
    func prepareIfNeeded() {
        guard supportsHaptics else { return }
        do {
            if engine == nil {
                engine = try CHHapticEngine()
            }
            try AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default, options: [])
            try AVAudioSession.sharedInstance().setActive(true, options: [])
            try engine?.start()
        } catch {
            engine = nil
            supportsHaptics = false
        }
    }
    
    func success() {
        guard supportsHaptics else { return }
        prepareIfNeeded()
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }
    
    func error() {
        guard supportsHaptics else { return }
        prepareIfNeeded()
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.error)
    }
}
