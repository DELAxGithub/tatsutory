import SwiftUI

enum L10n {
    static func key(_ key: String) -> LocalizedStringKey {
        LocalizedStringKey(key)
    }
    
    static func string(_ key: String, _ args: CVarArg...) -> String {
        let format = NSLocalizedString(key, comment: "")
        if args.isEmpty {
            return format
        }
        return String(format: format, locale: Locale.current, arguments: args)
    }
}
