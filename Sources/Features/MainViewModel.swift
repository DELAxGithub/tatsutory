import SwiftUI
import UIKit

@MainActor
class MainViewModel: ObservableObject {
    @Published var showingSettings = false
    @Published var showingCamera = false
    @Published var showingPreview = false
    @Published var isLoading = false
    @Published var generatedPlan: Plan?
    @Published var showingConsentDialog = false
    @Published var consentMessage = ""
    
    private let intentStore = IntentSettingsStore.shared
    private let consentStore = ConsentStore.shared
    
    var hasAPIKey: Bool { !Secrets.load().isEmpty }
    
    func checkAPIKey() {
        if !hasAPIKey { showingSettings = true }
    }
    
    func handleTakePhotoTapped() {
        if !consentStore.hasCompletedPrompt {
            consentMessage = "写真をAIに送信してラベル補正を行います。送信せずに端末内だけで処理することもできます。"
            showingConsentDialog = true
        } else {
            showingCamera = true
        }
    }
    
    func recordConsent(_ allowed: Bool) {
        consentStore.hasConsentedToVisionUpload = allowed
        consentStore.hasCompletedPrompt = true
        showingConsentDialog = false
        showingCamera = true
    }
    
    func handleCapturedImage(_ image: UIImage) {
        Task { await generatePlan(from: image) }
    }
    
    func generatePlan(from image: UIImage) async {
        isLoading = true
        
        let planner = TidyPlanner()
        let locale = UserLocale(country: "CA", city: "Toronto")
        let allowNetwork = hasAPIKey && consentStore.hasConsentedToVisionUpload
        generatedPlan = await planner.generate(from: image, locale: locale, allowNetwork: allowNetwork)
        
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
