import Foundation
import UIKit

class TidyPlanner {
    private let apiKey: String
    
    init() {
        self.apiKey = Secrets.load()
    }
    
    func generate(from image: UIImage, locale: UserLocale, allowNetwork: Bool) async throws -> Plan {
        if !allowNetwork || apiKey.isEmpty {
            return FallbackPlanner.generatePlan(locale: locale)
        }
        
        do {
            let openAIService = OpenAIService(apiKey: apiKey)
            return try await openAIService.generatePlan(from: image, locale: locale)
        } catch {
            print("AI generation failed: \(error)")
            return FallbackPlanner.generatePlan(locale: locale)
        }
    }
    
    static func fallbackPlan() -> Plan {
        return FallbackPlanner.generatePlan()
    }
}