import Foundation

extension ExitTag {
    var localizationKey: String {
        switch self {
        case .sell: return "exit_tag.sell"
        case .give: return "exit_tag.give"
        case .recycle: return "exit_tag.recycle"
        case .trash: return "exit_tag.trash"
        case .keep: return "exit_tag.keep"
        }
    }
    
    var localizedName: String {
        L10n.string(localizationKey)
    }
}
