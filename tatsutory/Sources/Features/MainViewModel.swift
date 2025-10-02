import SwiftUI
import UIKit

@MainActor
class MainViewModel: ObservableObject {
    @Published var showingSettings = false
    @Published var showingCamera = false
    @Published var showingPreview = false
    @Published var isLoading = false
    @Published var generatedPlan: PlanResult?
    @Published var showingConsentDialog = false
    @Published var consentMessage = ""
    
    private let intentStore = IntentSettingsStore.shared
    private let consentStore = ConsentStore.shared
#if DEBUG
    @AppStorage("debug.useSamplePhoto") private var useSamplePhoto = true
#endif

    var hasAPIKey: Bool { !Secrets.load().isEmpty }
    
    func checkAPIKey() {
        if !hasAPIKey { showingSettings = true }
    }

    func handleTakePhotoTapped() {
#if DEBUG
        if useSamplePhoto {
            useSampleImage()
            return
        }
#endif
        if !consentStore.hasCompletedPrompt {
            consentMessage = L10n.string("main.consent_message")
            showingConsentDialog = true
        } else {
            showingCamera = true
        }
    }
    
    func recordConsent(_ allowed: Bool) {
        consentStore.hasConsentedToVisionUpload = allowed
        consentStore.hasCompletedPrompt = true
        intentStore.update { $0.llm.consent = allowed }
        showingConsentDialog = false
        showingCamera = true
        TelemetryTracker.shared.trackAISettingsSnapshot(
            featureEnabled: FeatureFlags.intentSettingsV1,
            consent: allowed,
            hasAPIKey: hasAPIKey,
            allowNetwork: FeatureFlags.intentSettingsV1 && hasAPIKey && allowed
        )
    }
    
    func handleCapturedImage(_ image: UIImage) {
        Task { await generatePlan(from: image) }
    }

#if DEBUG
    func useSampleImage() {
        guard let url = Bundle.main.url(forResource: "IMG_0162", withExtension: "jpeg"),
              let data = try? Data(contentsOf: url),
              let image = UIImage(data: data) else {
            print("[Debug] Failed to load IMG_0162.jpeg from bundle")
            return
        }
        Task { await generatePlan(from: image) }
    }
#endif

    func generatePlan(from image: UIImage) async {
        isLoading = true

        let planner = TidyPlanner()
        let settings = intentStore.value
        let allowNetwork = FeatureFlags.intentSettingsV1 && hasAPIKey && settings.llm.consent
        generatedPlan = await planner.generate(from: image, allowNetwork: allowNetwork)
        
        showingPreview = true
        isLoading = false
        TelemetryTracker.shared.flushIfNeeded()
    }
    
    func handlePlanCompletion(success: Bool) {
        if success {
            generatedPlan = nil
            showingPreview = false
        }
    }
}
