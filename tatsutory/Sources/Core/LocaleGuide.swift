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
        let isJapanese = locale.country.uppercased() == "JP" || (Locale.preferredLanguages.first ?? "en").hasPrefix("ja")
        switch exitTag {
        case .sell:
            if isJapanese {
                return [
                    "スマホで全体・キズの写真を撮る（3枚程度）",
                    "メルカリで同カテゴリの相場を検索し価格を決める",
                    "タイトルと説明文を下書き保存しておく"
                ]
            }
            return [
                "Shoot 2-3 clear photos showing front, back, and any flaws",
                "Scan recent marketplace listings to set a realistic price",
                "Draft the listing title and description and save it"
            ]
        case .give:
            if isJapanese {
                return [
                    "サッと動作や汚れをチェックする",
                    "地域SNS/ジモティーに『譲ります』下書きを作る",
                    "受け渡し場所と日時の候補をメモする"
                ]
            }
            return [
                "Do a quick condition check",
                "Draft a 'free pickup' post in local groups",
                "Decide a pickup place and time window"
            ]
        case .recycle:
            if isJapanese {
                return [
                    "自治体サイトで品目名を検索してルールを確認",
                    "申し込み窓口や持ち込み先URLをブックマーク",
                    "回収前日に運び出しやすい場所へ移動"
                ]
            }
            if locale.country.uppercased() == "CA" && locale.city.lowercased().contains("toronto") {
                return [
                    "Check Toronto Waste Wizard for guidelines",
                    "Find nearest drop-off location",
                    "Bundle similar items together",
                    "Schedule drop-off trip"
                ]
            }
            return [
                "Check local recycling guidelines for the item",
                "Bookmark the drop-off booking page or location",
                "Stage the item near the door the day before drop-off"
            ]
        case .trash:
            if isJapanese {
                return [
                    "収集日カレンダーで該当日を確認",
                    "指定袋にまとめて縛っておく",
                    "前夜に玄関付近へ仮置きする"
                ]
            }
            return [
                "Look up the correct pickup day",
                "Bag and tie items according to sorting rules",
                "Stage the bag by the door the night before"
            ]
        case .keep:
            if isJapanese {
                return [
                    "軽く掃除してホコリを落とす",
                    "保管場所とラベルを決めてまとめる",
                    "次回見直し日をメモしておく"
                ]
            }
            return [
                "Dust or wipe the item quickly",
                "Group it in a clear storage spot with a label",
                "Note a date to review whether it still sparks joy"
            ]
        }
    }
}
