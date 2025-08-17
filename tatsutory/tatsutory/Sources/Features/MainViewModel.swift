import SwiftUI
import UIKit

@MainActor
class MainViewModel: ObservableObject {
    @Published var showingSettings = false
    @Published var showingCamera = false
    @Published var showingPreview = false
    @Published var isLoading = false
    @Published var generatedPlan: Plan?
    
    var hasAPIKey: Bool { !Secrets.load().isEmpty }
    
    func checkAPIKey() {
        if !hasAPIKey { showingSettings = true }
    }
    
    func handleCapturedImage(_ image: UIImage) {
        Task { await generatePlan(from: image) }
    }
    
    func generatePlan(from image: UIImage) async {
        isLoading = true
        
        do {
            let planner = TidyPlanner()
            let locale = UserLocale(country: "CA", city: "Toronto")
            generatedPlan = try await planner.generate(from: image, locale: locale, allowNetwork: hasAPIKey)
        } catch {
            generatedPlan = TidyPlanner.fallbackPlan()
        }
        
        showingPreview = true
        isLoading = false
    }
    
    func handlePlanCompletion(success: Bool) {
        if success {
            generatedPlan = nil
            showingPreview = false
        }
    }
}