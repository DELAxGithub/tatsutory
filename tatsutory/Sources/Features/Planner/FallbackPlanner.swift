import Foundation

struct FallbackPlanner {
    static func generatePlan(locale: UserLocale = UserLocale(country: "CA", city: "Toronto")) -> Plan {
        let tasks = [
            createSellTask(),
            createRecycleTask(),
            createGiveTask()
        ]
        
        return Plan(
            project: "Fallback Moving Plan",
            locale: locale,
            tasks: tasks
        )
    }
    
    private static func createSellTask() -> TidyTask {
        return TidyTask(
            id: "FB01",
            title: "Sell large electronics (TV, etc.)",
            category: nil,
            note: nil,
            tips: nil,
            area: "living",
            exit_tag: .sell,
            priority: 4,
            effort_min: 30,
            labels: ["sell", "electronics"],
            checklist: [
                "Check model number on back",
                "Take photos: front, sides, back, model label",
                "Research recent sold prices",
                "Post on Facebook Marketplace"
            ],
            links: ["https://www.facebook.com/marketplace/"],
            url: "https://www.facebook.com/marketplace/",
            due_at: DateHelper.futureDate(days: 3),
            photoAssetID: nil
        )
    }

    private static func createRecycleTask() -> TidyTask {
        return TidyTask(
            id: "RC01",
            title: "Bundle cables for e-waste drop-off",
            category: nil,
            note: nil,
            tips: nil,
            area: "electronics",
            exit_tag: .recycle,
            priority: 2,
            effort_min: 15,
            labels: ["recycle", "cables"],
            checklist: [
                "Collect all unused cables",
                "Find nearest e-waste location",
                "Schedule drop-off trip"
            ],
            links: ["https://www.toronto.ca/services-payments/recycling-organics-garbage/waste-wizard/"],
            url: nil,
            due_at: DateHelper.futureDate(days: 7),
            photoAssetID: nil
        )
    }

    private static func createGiveTask() -> TidyTask {
        return TidyTask(
            id: "GV01",
            title: "Give away books and magazines",
            category: nil,
            note: nil,
            tips: nil,
            area: "books",
            exit_tag: .give,
            priority: 2,
            effort_min: 20,
            labels: ["give", "books"],
            checklist: [
                "Sort books by condition",
                "Post good ones in local groups",
                "Remainder to Little Free Library"
            ],
            links: ["https://www.facebook.com/groups/"],
            url: nil,
            due_at: DateHelper.futureDate(days: 5),
            photoAssetID: nil
        )
    }
}

struct DateHelper {
    static func futureDate(days: Int) -> String {
        let futureDate = Date().addingTimeInterval(86400 * TimeInterval(days))
        return ISO8601DateFormatter().string(from: futureDate)
    }
}
