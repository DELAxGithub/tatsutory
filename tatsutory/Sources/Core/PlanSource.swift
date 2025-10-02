import Foundation

enum PlanSource: Equatable {
    case local
    case openAI(requestId: String)
    case rateLimited
}

struct PlanResult {
    let plan: Plan
    let source: PlanSource
    let notice: String?

    init(plan: Plan, source: PlanSource, notice: String? = nil) {
        self.plan = plan
        self.source = source
        self.notice = notice
    }
}
