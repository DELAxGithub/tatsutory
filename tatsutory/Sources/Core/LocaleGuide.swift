import Foundation

struct LocaleGuide {
    static func getDefaultLinks(for locale: UserLocale, exitTag: ExitTag) -> [String] {
        switch (locale.country.uppercased(), exitTag) {
        case ("CA", .sell):
            return [
                "https://www.facebook.com/marketplace/",
                "https://www.kijiji.ca/"
            ]
        case ("CA", .recycle):
            if locale.city.lowercased().contains("toronto") {
                return ["https://www.toronto.ca/services-payments/recycling-organics-garbage/waste-wizard/"]
            }
            return ["https://www.canada.ca/en/environment-climate-change/services/managing-reducing-waste/municipal-solid/electronics.html"]
        case ("CA", .give):
            return [
                "https://www.facebook.com/groups/",
                "https://www.freecycle.org/"
            ]
        case ("JP", .sell):
            return [
                "https://www.mercari.com/jp/",
                "https://auctions.yahoo.co.jp/",
                "https://jmty.jp/"
            ]
        case ("JP", .recycle):
            return ["https://www.env.go.jp/recycle/"] // General recycling info
        case ("JP", .give):
            return [
                "https://jmty.jp/",
                "https://www.facebook.com/groups/"
            ]
        default:
            return []
        }
    }
    
    static func getTemplateChecklist(for exitTag: ExitTag, locale: UserLocale) -> [String] {
        switch exitTag {
        case .sell:
            return [
                "Take clear photos from multiple angles",
                "Research recent sold prices",
                "Write detailed description with condition",
                "Post on marketplace platform",
                "Respond to inquiries promptly"
            ]
        case .give:
            return [
                "Check item condition",
                "Take photos for posting",
                "Post in local community groups",
                "Arrange pickup details"
            ]
        case .recycle:
            if locale.country.uppercased() == "CA" && locale.city.lowercased().contains("toronto") {
                return [
                    "Check Toronto Waste Wizard for guidelines",
                    "Find nearest drop-off location",
                    "Bundle similar items together",
                    "Schedule drop-off trip"
                ]
            }
            return [
                "Research local recycling guidelines",
                "Find appropriate drop-off location",
                "Prepare items for drop-off"
            ]
        case .trash:
            return [
                "Check pickup schedule",
                "Bag items appropriately",
                "Set out on collection day"
            ]
        case .keep:
            return [
                "Clean and organize",
                "Find appropriate storage location",
                "Label if necessary"
            ]
        }
    }
}