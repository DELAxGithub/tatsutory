import Foundation
import UIKit

struct PromptBuilder {
    // Base schema - minItems will be added dynamically based on detected item count
    private static let baseSchema = #"{"type":"object","additionalProperties":false,"properties":{"tasks":{"type":"array","items":{"type":"object","additionalProperties":false,"properties":{"id":{"type":"string"},"title":{"type":"string"},"category":{"type":"string"},"exitTag":{"type":"string","enum":["SELL","GIVE","RECYCLE","TRASH","KEEP"]},"checklist":{"type":"array","items":{"type":"string"}},"tips":{"type":"string"},"links":{"type":"array","items":{"type":"string"}},"estimatedMinutes":{"type":"integer"},"note":{"type":"string"}},"required":["id","title","category","exitTag","checklist","tips","links","estimatedMinutes","note"]}}},"required":["tasks"]}"#

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

        if isJapanese {
            let regionalLinks = buildRegionalLinksGuide(locale: locale, isJapanese: true)

            systemPrompt = """
            片付け専門家として、1アイテム=1タスクで作成してください。

            【必須】
            - アイテム\(items.count)個 → タスク\(items.count)個
            - タイトルに具体的なアイテム名
            - category: アイテムの分類（家電/家具/衣類/食器/雑貨など）
            - チェックリスト2-3項目（簡潔に）
            - tips: そのカテゴリ/アイテム固有の販売・処分のコツ（1文）
            - note: 相場感や注意点（1文）
            - links: 処分方法に応じた地域の参考リンク（下記から選択または類似サイト）

            処分方法: SELL/GIVE/RECYCLE/TRASH/KEEP

            \(regionalLinks)
            """

            let itemsList = items.enumerated().map {
                "\($0.offset + 1). \(translateToJapanese($0.element.label))"
            }.joined(separator: "\n")

            userPrompt = """
            アイテム:
            \(itemsList)

            設定: \(purposeDescription(settings.purpose, isJapanese: true)) | \(locale.city), \(locale.country)

            例:
            {"tasks":[{"id":"1","title":"TVを売却","category":"家電","exitTag":"SELL","checklist":["型番確認","動作確認"],"tips":"大型家電は型番・年式を明記すると問い合わせが増える","links":["https://www.mercari.com/jp/"],"estimatedMinutes":30,"note":"50型以上は需要高、¥10,000-50,000"}]}

            \(items.count)個の独立したタスクをJSONで出力
            """
        } else {
            let regionalLinks = buildRegionalLinksGuide(locale: locale, isJapanese: false)

            systemPrompt = """
            Decluttering expert: 1 item = 1 task.

            【REQUIRED】
            - \(items.count) items → \(items.count) tasks
            - Specific item name in title
            - category: Item classification (electronics/furniture/clothing/kitchenware/misc)
            - 2-3 checklist items (brief)
            - tips: Category/item-specific selling/disposal tip (1 sentence)
            - note: Price range or caution (1 sentence)
            - links: Regional reference links based on disposal method (choose from below or similar)

            Methods: SELL/GIVE/RECYCLE/TRASH/KEEP

            \(regionalLinks)
            """

            let itemsList = items.enumerated().map { "\($0.offset + 1). \($0.element.label)" }.joined(separator: "\n")

            userPrompt = """
            Items:
            \(itemsList)

            Context: \(settings.goalDateISO) | \(purposeDescription(settings.purpose, isJapanese: false)) | \(locale.city), \(locale.country)

            Example:
            {"tasks":[{"id":"1","title":"Sell TV","category":"electronics","exitTag":"SELL","checklist":["Check model","Test display"],"tips":"Include model number and year to get more inquiries","links":["https://www.facebook.com/marketplace/"],"estimatedMinutes":30,"note":"50\"+ TVs high demand, $100-500"}]}

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
            case .overview: return "引越しの総量把握と優先順位"
            case .move_fast: return "とにかく早く片付けたい"
            case .move_value: return "価値ある物を売って手放したい"
            case .cleanup: return "身の回りを整理整頓したい"
            case .legacy_hidden: return "家族と相談しながら保管したい"
            }
        }
        switch purpose {
        case .overview: return "Moving overview and prioritization"
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

    private static func buildRegionalLinksGuide(locale: UserLocale, isJapanese: Bool) -> String {
        let country = locale.country.uppercased()
        let city = locale.city.lowercased()

        if isJapanese {
            if country == "JP" {
                return """
                【地域別参考リンク（日本）】
                - SELL: https://www.mercari.com/jp/ (メルカリ), https://auctions.yahoo.co.jp/ (ヤフオク), https://jmty.jp/ (ジモティー)
                - GIVE: https://jmty.jp/ (ジモティー), https://www.facebook.com/groups/ (地域SNS)
                - RECYCLE: https://www.env.go.jp/recycle/ (環境省リサイクル情報), 自治体の粗大ゴミ検索サイト
                """
            } else if country == "CA" {
                if city.contains("toronto") {
                    return """
                    【地域別参考リンク（トロント）】
                    - SELL: https://www.facebook.com/marketplace/, https://www.kijiji.ca/
                    - GIVE: https://www.facebook.com/groups/, https://www.freecycle.org/
                    - RECYCLE: https://www.toronto.ca/services-payments/recycling-organics-garbage/waste-wizard/ (トロント市ゴミ分別ガイド)
                    """
                }
                return """
                【地域別参考リンク（カナダ）】
                - SELL: https://www.facebook.com/marketplace/, https://www.kijiji.ca/
                - GIVE: https://www.facebook.com/groups/, https://www.freecycle.org/
                - RECYCLE: https://www.canada.ca/en/environment-climate-change/services/managing-reducing-waste/municipal-solid/electronics.html
                """
            }
        } else {
            if country == "JP" {
                return """
                【Regional Links (Japan)】
                - SELL: https://www.mercari.com/jp/ (Mercari), https://auctions.yahoo.co.jp/ (Yahoo Auctions), https://jmty.jp/ (Jimoty)
                - GIVE: https://jmty.jp/ (Jimoty), https://www.facebook.com/groups/ (local groups)
                - RECYCLE: https://www.env.go.jp/recycle/ (Ministry of Environment), local municipality waste search
                """
            } else if country == "CA" {
                if city.contains("toronto") {
                    return """
                    【Regional Links (Toronto, Canada)】
                    - SELL: https://www.facebook.com/marketplace/, https://www.kijiji.ca/
                    - GIVE: https://www.facebook.com/groups/, https://www.freecycle.org/
                    - RECYCLE: https://www.toronto.ca/services-payments/recycling-organics-garbage/waste-wizard/ (Toronto Waste Wizard)
                    """
                }
                return """
                【Regional Links (Canada)】
                - SELL: https://www.facebook.com/marketplace/, https://www.kijiji.ca/
                - GIVE: https://www.facebook.com/groups/, https://www.freecycle.org/
                - RECYCLE: https://www.canada.ca/en/environment-climate-change/services/managing-reducing-waste/municipal-solid/electronics.html
                """
            }
        }

        // Default fallback
        return isJapanese
            ? "【参考リンク】\n- SELL: フリマアプリやオークションサイト\n- GIVE: 地域のSNSグループ\n- RECYCLE: 自治体のリサイクルガイド"
            : "【Reference Links】\n- SELL: Marketplace apps or auction sites\n- GIVE: Local community groups\n- RECYCLE: Municipal recycling guide"
    }

    // MARK: - Overview Mode Prompt

    static func buildOverviewPrompt(image: UIImage, goalDate: String) -> (system: String, user: String) {
        let isJapanese = Locale.current.language.languageCode?.identifier == "ja"

        let systemPrompt: String
        let userPrompt: String

        if isJapanese {
            systemPrompt = """
            あなたは引越し・処分プランナーです。
            部屋の写真を分析し、引越しに向けた処分作業の優先順位を提案してください。

            【重要な視点】
            - 総量把握：部屋全体にどのくらいの物があり、処分すべき物の量を見積もる
            - 処分品分類：SELL（売る）、GIVE（譲る）、RECYCLE（処分）、KEEP（持っていく）の仕分け
            - サルベージ優先：まだ使える物・売れる物を見逃さない
            - ゴール日からの逆算：処分に時間がかかる物（売却、寄付手配）から着手

            【分析の優先順位】
            1. 大物・処分判断が重い物（家具・家電）→ 売却/処分に時間がかかる
            2. 量が多いエリア（クローゼット、収納棚）→ 仕分けに時間がかかる
            3. 売却価値がある物（ガジェット、家電、家具）→ 早めの出品が有利
            4. 日常生活への影響が少ない物 → 先に片付けても支障なし

            【時間見積もり】
            - 仕分け：1エリアあたり30-60分
            - 出品準備：写真撮影・説明文作成で物1つあたり10-30分
            - 処分手配：粗大ゴミ予約、寄付先調査などで30-60分

            【考え方】
            - 完璧な片付けではなく、「処分すべき物の洗い出し」が目的
            - 後から詳細な仕分けをするため、まずは物の総量とカテゴリを把握
            - 売却できる物は早めに出品（引越し直前では間に合わない）

            必ず以下のJSON形式で出力してください。
            """

            userPrompt = """
            この部屋の写真を分析し、引越しに向けた処分作業の優先順位を提案してください。
            ゴール日（引越し日）: \(goalDate)
            """
        } else {
            systemPrompt = """
            You are a moving and disposal planner.
            Analyze the room photo and suggest priorities for disposal tasks toward moving day.

            [Key Perspectives]
            - Volume Assessment: Estimate total items and disposal volume
            - Classification: SELL (sell), GIVE (donate), RECYCLE (dispose), KEEP (bring)
            - Salvage Priority: Don't miss valuable or usable items
            - Work Backward from Goal: Start with items requiring time (selling, donation arrangements)

            [Analysis Priority]
            1. Large items/heavy decisions (furniture, appliances) → Takes time to sell/dispose
            2. High-volume areas (closets, storage) → Takes time to sort
            3. Items with resale value (gadgets, electronics, furniture) → Early listing is advantageous
            4. Items with low daily impact → Can be dealt with first without disruption

            [Time Estimates]
            - Sorting: 30-60 min per area
            - Listing prep: 10-30 min per item (photos, descriptions)
            - Disposal arrangements: 30-60 min (bulk waste booking, donation research)

            [Approach]
            - Goal is "identifying disposal items", not perfect organization
            - Get total volume and categories first, detailed sorting comes later
            - List sellable items early (won't make it last minute before moving)

            Output must be in the following JSON format.
            """

            userPrompt = """
            Analyze this room photo and suggest disposal task priorities for moving day.
            Goal date (moving day): \(goalDate)
            """
        }

        return (systemPrompt, userPrompt)
    }

    static func overviewSchema() -> String {
        return """
        {
          "type": "object",
          "required": ["overview", "priority_areas", "quick_start"],
          "additionalProperties": false,
          "properties": {
            "overview": {
              "type": "object",
              "required": ["状態", "推定時間", "主な課題"],
              "additionalProperties": false,
              "properties": {
                "状態": {"type": "string", "description": "物の総量と処分対象の見積もり"},
                "推定時間": {"type": "string", "description": "仕分け・処分手配の総時間"},
                "主な課題": {"type": "array", "items": {"type": "string"}, "maxItems": 3}
              }
            },
            "priority_areas": {
              "type": "array",
              "minItems": 3,
              "maxItems": 5,
              "items": {
                "type": "object",
                "required": ["順位", "エリア名", "理由", "作業内容", "所要時間", "難易度", "効果"],
                "additionalProperties": false,
                "properties": {
                  "順位": {"type": "integer", "minimum": 1},
                  "エリア名": {"type": "string"},
                  "理由": {"type": "string"},
                  "作業内容": {
                    "type": "array",
                    "items": {"type": "string"},
                    "minItems": 2,
                    "maxItems": 4
                  },
                  "所要時間": {"type": "string"},
                  "難易度": {"enum": ["簡単", "普通", "難しい"]},
                  "効果": {"enum": ["大", "中", "小"]}
                }
              }
            },
            "quick_start": {
              "type": "string",
              "description": "最初の30分で処分対象の総量把握のために何をすべきか"
            }
          }
        }
        """
    }

    static func buildOverviewToTasksPrompt(plan: OverviewPlan) -> (system: String, user: String) {
        let isJapanese = Locale.current.language.languageCode?.identifier == "ja"

        let systemPrompt: String
        let userPrompt: String

        if isJapanese {
            systemPrompt = """
            あなたは引越しタスク作成の専門家です。
            初手モードの優先順位提案をもとに、実行可能なタスクリストを作成します。

            【タスク作成の原則】
            1. 各優先エリアを2-4個の具体的なタスクに分解
            2. タスクは実行可能な粒度（15-60分程度）
            3. exit_tagは処分方法を反映：SELL/GIVE/RECYCLE/KEEP
            4. 優先度は順位に応じて設定（1位=5, 2位=4, 3位以降=3）
            5. チェックリストは具体的な作業手順
            """

            userPrompt = """
            以下の初手モード分析結果から、実行可能なタスクリストを作成してください。

            【全体概要】
            状態: \(plan.overview.state)
            推定時間: \(plan.overview.estimatedTime)
            主な課題: \(plan.overview.mainIssues.joined(separator: ", "))

            【優先エリア】
            \(plan.priorityAreas.map { area in
                """
                #\(area.rank) \(area.areaName)
                理由: \(area.reason)
                作業: \(area.tasks.joined(separator: ", "))
                所要時間: \(area.timeRequired)
                難易度: \(area.difficulty.rawValue)
                効果: \(area.impact.rawValue)
                """
            }.joined(separator: "\n\n"))

            【最初の30分】
            \(plan.quickStart)

            上記をもとに、優先順位の高いエリアから実行可能なタスクを作成してください。
            """
        } else {
            systemPrompt = """
            You are a moving task creation expert.
            Create an actionable task list based on the overview mode priority recommendations.

            [Task Creation Principles]
            1. Break each priority area into 2-4 specific tasks
            2. Tasks should be actionable in 15-60 minutes
            3. exit_tag reflects disposal method: SELL/GIVE/RECYCLE/KEEP
            4. Priority based on rank (1st=5, 2nd=4, 3rd+=3)
            5. Checklist contains specific action steps
            """

            userPrompt = """
            Create an actionable task list from the following overview mode analysis.

            [Overview]
            State: \(plan.overview.state)
            Estimated Time: \(plan.overview.estimatedTime)
            Main Issues: \(plan.overview.mainIssues.joined(separator: ", "))

            [Priority Areas]
            \(plan.priorityAreas.map { area in
                """
                #\(area.rank) \(area.areaName)
                Reason: \(area.reason)
                Tasks: \(area.tasks.joined(separator: ", "))
                Time Required: \(area.timeRequired)
                Difficulty: \(area.difficulty.rawValue)
                Impact: \(area.impact.rawValue)
                """
            }.joined(separator: "\n\n"))

            [First 30 Minutes]
            \(plan.quickStart)

            Based on the above, create actionable tasks starting from the highest priority areas.
            """
        }

        return (systemPrompt, userPrompt)
    }
}
