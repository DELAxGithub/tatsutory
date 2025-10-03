import Foundation

struct PromptBuilder {
    // Base schema - minItems will be added dynamically based on detected item count
    private static let baseSchema = #"{"type":"object","additionalProperties":false,"properties":{"tasks":{"type":"array","items":{"type":"object","additionalProperties":false,"properties":{"id":{"type":"string"},"title":{"type":"string"},"category":{"type":"string"},"exitTag":{"type":"string","enum":["SELL","GIVE","RECYCLE","TRASH","KEEP"]},"dueDate":{"type":"string"},"checklist":{"type":"array","items":{"type":"string"}},"tips":{"type":"string"},"links":{"type":"array","items":{"type":"string"}},"estimatedMinutes":{"type":"integer"},"note":{"type":"string"}},"required":["id","title","category","exitTag","dueDate","checklist","tips","links","estimatedMinutes","note"]}}},"required":["tasks"]}"#

    static func schema(for itemCount: Int) -> String {
        // Parse base schema and add minItems constraint
        guard let data = baseSchema.data(using: .utf8),
              var schemaDict = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              var properties = schemaDict["properties"] as? [String: Any],
              var tasks = properties["tasks"] as? [String: Any] else {
            return baseSchema
        }

        // Add minItems and maxItems to enforce exact count
        tasks["minItems"] = itemCount
        tasks["maxItems"] = itemCount
        properties["tasks"] = tasks
        schemaDict["properties"] = properties

        // Convert back to JSON string
        guard let updatedData = try? JSONSerialization.data(withJSONObject: schemaDict),
              let updatedString = String(data: updatedData, encoding: .utf8) else {
            return baseSchema
        }

        return updatedString
    }

    private static let isoFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    static func build(items: [DetectedItem],
                      settings: IntentSettings,
                      locale: UserLocale) -> (system: String, user: String) {
        let systemLanguage = Locale.preferredLanguages.first ?? "en"
        let isJapanese = locale.country.uppercased() == "JP" || systemLanguage.hasPrefix("ja")

        let systemPrompt: String
        let userPrompt: String

        // アイテム情報を構造化
        let itemsData = items.map { item in
            [
                "label": item.label,
                "confidence": item.confidence,
                "size": sizeCategory(for: item.areaRatio)
            ]
        }

        if isJapanese {
            systemPrompt = """
            片付け専門家として、1アイテム=1タスクで作成してください。

            【必須】
            - アイテム\(items.count)個 → タスク\(items.count)個
            - タイトルに具体的なアイテム名
            - category: アイテムの分類（家電/家具/衣類/食器/雑貨など）
            - チェックリスト2-3項目（簡潔に）
            - tips: そのカテゴリ/アイテム固有の販売・処分のコツ（1文）
            - note: 相場感や注意点（1文）

            処分方法: SELL/GIVE/RECYCLE/TRASH/KEEP
            """

            let itemsList = items.enumerated().map {
                "\($0.offset + 1). \(translateToJapanese($0.element.label))"
            }.joined(separator: "\n")

            userPrompt = """
            アイテム:
            \(itemsList)

            設定: \(settings.goalDateISO) | \(purposeDescription(settings.purpose, isJapanese: true)) | \(locale.city), \(locale.country)

            例:
            {"tasks":[{"id":"1","title":"TVを売却","category":"家電","exitTag":"SELL","dueDate":"2025-10-09T00:00:00Z","checklist":["型番確認","動作確認"],"tips":"大型家電は型番・年式を明記すると問い合わせが増える","links":["https://www.mercari.com/jp/"],"estimatedMinutes":30,"note":"50型以上は需要高、¥10,000-50,000"}]}

            \(items.count)個の独立したタスクをJSONで出力
            """
        } else {
            systemPrompt = """
            Decluttering expert: 1 item = 1 task.

            【REQUIRED】
            - \(items.count) items → \(items.count) tasks
            - Specific item name in title
            - category: Item classification (electronics/furniture/clothing/kitchenware/misc)
            - 2-3 checklist items (brief)
            - tips: Category/item-specific selling/disposal tip (1 sentence)
            - note: Price range or caution (1 sentence)

            Methods: SELL/GIVE/RECYCLE/TRASH/KEEP
            """

            let itemsList = items.enumerated().map { "\($0.offset + 1). \($0.element.label)" }.joined(separator: "\n")

            userPrompt = """
            Items:
            \(itemsList)

            Context: \(settings.goalDateISO) | \(purposeDescription(settings.purpose, isJapanese: false)) | \(locale.city), \(locale.country)

            Example:
            {"tasks":[{"id":"1","title":"Sell TV","category":"electronics","exitTag":"SELL","dueDate":"2025-10-09T00:00:00Z","checklist":["Check model","Test display"],"tips":"Include model number and year to get more inquiries","links":["https://www.facebook.com/marketplace/"],"estimatedMinutes":30,"note":"50\"+ TVs high demand, $100-500"}]}

            Output \(items.count) separate tasks in JSON
            """
        }

        return (systemPrompt, userPrompt)
    }

    private static func sizeCategory(for areaRatio: CGFloat) -> String {
        if areaRatio > 0.15 {
            return "large"
        } else if areaRatio > 0.05 {
            return "medium"
        } else {
            return "small"
        }
    }

    private static func translateToJapanese(_ englishLabel: String) -> String {
        let dictionary: [String: String] = [
            "Television": "テレビ",
            "TV": "テレビ",
            "Soundbar": "サウンドバー",
            "Sound bar": "サウンドバー",
            "Coffee table": "コーヒーテーブル",
            "Side table": "サイドテーブル",
            "Floor lamp": "フロアランプ",
            "Lamp": "ランプ",
            "Sofa": "ソファ",
            "Couch": "ソファ",
            "Chair": "椅子",
            "Table": "テーブル",
            "Desk": "デスク",
            "Bed": "ベッド",
            "Bookshelf": "本棚",
            "Cabinet": "キャビネット",
            "Dresser": "ドレッサー",
            "Mirror": "鏡",
            "Rug": "ラグ",
            "Carpet": "カーペット",
            "Curtain": "カーテン",
            "Plant": "観葉植物",
            "Picture": "絵画",
            "Clock": "時計",
            "Vase": "花瓶",
            "Box": "箱",
            "Basket": "バスケット"
        ]
        return dictionary[englishLabel] ?? englishLabel
    }

    private static func purposeDescription(_ purpose: Purpose, isJapanese: Bool) -> String {
        if isJapanese {
            switch purpose {
            case .move_fast: return "とにかく早く片付けたい"
            case .move_value: return "価値ある物を売って手放したい"
            case .cleanup: return "身の回りを整理整頓したい"
            case .legacy_hidden: return "家族と相談しながら保管したい"
            }
        }
        switch purpose {
        case .move_fast: return "Move quickly"
        case .move_value: return "Maximize resale value"
        case .cleanup: return "General cleanup"
        case .legacy_hidden: return "Keep for family discussion"
        }
    }

    private static func jsonString(from object: Any) -> String {
        guard JSONSerialization.isValidJSONObject(object),
              let data = try? JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted]) else {
            return "[]"
        }
        return String(data: data, encoding: .utf8) ?? "[]"
    }
}
