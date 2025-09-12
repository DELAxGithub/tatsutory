import Foundation

public final class TidyPlanner {
    private let apiKey: String?
    
    public init(apiKey: String?) {
        self.apiKey = apiKey
    }
    
    /// Generates a plan from image data. Returns a fallback plan if network is disabled or API fails.
    public func generate(from imageData: Data, locale: UserLocale, allowNetwork: Bool) async -> Plan {
        guard allowNetwork, let key = apiKey, !key.isEmpty else {
            return FallbackPlanner.generatePlan(locale: locale)
        }
        do {
            let openAI = OpenAIService(apiKey: key)
            return try await openAI.generatePlan(from: imageData, locale: locale)
        } catch {
            return FallbackPlanner.generatePlan(locale: locale)
        }
    }
    
    public static func fallbackPlan(locale: UserLocale = UserLocale(country: "CA", city: "Toronto")) -> Plan {
        FallbackPlanner.generatePlan(locale: locale)
    }
}

