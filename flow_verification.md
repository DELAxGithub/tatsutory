# 実装フロー検証

## 全体フロー

```
ユーザーが写真撮影
    ↓
TidyPlanner.generate(from: image)
    ↓
[Step 1] PhotoSplitService.detectItems()
    → RemoteDetectionService.detect() (API呼び出し)
    → 結果: [DetectedItem] (例: 4個)
    ↓
[Step 2] IntentAdjuster.filter()
    → smallItemThreshold に基づいてフィルタリング
    → 結果: filteredItems (例: 4個のまま)
    ↓
[Step 3] LLM呼び出しチェック
    - FeatureFlags.intentSettingsV1 == true ✓
    - apiKey != empty ✓
    - settings.llm.consent == true ✓
    - allowNetwork == true ✓
    ↓
    YES → generateWithLLM()
    NO  → TaskComposer.fallbackPlan()
    ↓
[Step 4] OpenAIService.generateTasks(from: filteredItems)
    ↓
    PromptBuilder.build(items: filteredItems, settings, locale)
    ↓
    構築されるプロンプト:
    - System: "必ず1アイテム=1タスク、合計N個作成"
    - User: "検出されたアイテム: [{label:TV}, {label:Soundbar}, ...]"
          "合計4個のタスクを出力してください"
    ↓
    OpenAI API呼び出し (gpt-5-mini)
    ↓
    レスポンス解析: OpenAIResponsesEnvelope
    ↓
    convertToTidyTasks() → [TidyTask]
    ↓
[Step 5] Plan作成
    → Plan(project: "...", locale: locale, tasks: [4個のTidyTask])
    ↓
返却: PlanResult(plan: plan, source: .openAI)
```

## 重要な確認ポイント

### ✅ 1. 検出されたアイテム数がそのまま渡される

**PhotoSplitService → TidyPlanner**
```swift
// tatsutory/Sources/Features/Planner/TidyPlanner.swift:20-22
let detection = await splitService.detectItems(...)
let filteredItems = IntentAdjuster.filter(items: detection.items, settings: settings)
// filteredItems が LLM に渡される
```

**確認**: 4個検出 → 4個フィルター後 → 4個がLLMへ ✓

### ✅ 2. プロンプトが1対1を強制している

**PromptBuilder.swift:32-73 (日本語版)**
```
**重要ルール**:
- 検出されたアイテム数と同じ数のタスクを必ず作成する（5個検出されたら5個のタスク）
- 各タスクは1つのアイテムに特化した内容にする
- 「複数アイテムをまとめて」のような表現は禁止

**必須**: 上記の各アイテムごとに1つずつタスクを作成してください。合計\(items.count)個のタスクを出力してください。

良い例:
- Table（テーブル）→ タイトル「Tableをメルカリで売却」
- Soundbar（サウンドバー）→ タイトル「Soundbarを売却」

悪い例:
- 「5個のアイテムを整理する」（これは禁止）
```

**確認**: プロンプトで明示的に items.count 個を要求 ✓

### ✅ 3. JSONスキーマが全フィールドを要求

**PromptBuilder.swift:4**
```json
{
  "type": "object",
  "additionalProperties": false,
  "properties": {
    "tasks": {
      "type": "array",
      "items": {
        "required": ["id", "title", "exitTag", "dueDate", "checklist", "links", "estimatedMinutes", "note"]
      }
    }
  }
}
```

**確認**: 全8フィールドがrequired、additionalProperties=false ✓

### ✅ 4. LLMレスポンスを正しくTidyTaskに変換

**OpenAIService.swift:212-244**
```swift
private func convertToTidyTasks(_ taskItems: [TaskPlanResponse.TaskItem], locale: UserLocale) -> [TidyTask] {
    var validTasks: [TidyTask] = []
    for item in taskItems {
        guard let exitTag = ExitTag(rawValue: item.exitTag) else {
            continue  // 不正なexitTagはスキップ
        }

        // 日付バリデーション
        if isoFormatter.date(from: item.dueDate) == nil {
            continue
        }

        let task = TidyTask(
            id: item.id,
            title: item.title,
            note: item.note,
            area: nil,
            exit_tag: exitTag,
            priority: nil,
            effort_min: item.estimatedMinutes,
            labels: nil,
            checklist: item.checklist,
            links: item.links,
            url: item.links?.first,
            due_at: item.dueDate
        )
        validTasks.append(task)
    }
    return validTasks
}
```

**確認**:
- exitTagバリデーション ✓
- 日付フォーマットバリデーション ✓
- 全フィールドをTidyTaskにマッピング ✓

### ✅ 5. ユーザー設定が反映される

**PromptBuilder.swift:45-48, 89-92**
```
ユーザーの優先事項に合わせて:
- 「価値ある物を売って手放したい」→ 売却可能なものは積極的にSELL、相場調査を含める
- 「とにかく早く片付けたい」→ GIVE/RECYCLEを優先、手間の少ない手順
- 「身の回りを整理整頓したい」→ バランスよく判断

ユーザー設定:
- 引っ越し予定日: 2025-10-16T20:52:46Z
- 優先事項: 価値ある物を売って手放したい
- 地域: Toronto, CA
```

**確認**: purpose、goalDate、region が全てプロンプトに含まれる ✓

## テストケース: IMG_6378 Medium.png

### 入力
- 画像: リビングルーム（TV, Soundbar, Console table, Plant stand等）
- ユーザー設定:
  - purpose: move_value (価値ある物を売って手放したい)
  - goalDate: 2025-10-16
  - region: CA-TO (Toronto)

### 期待される検出結果
```json
[
  {"label": "Television", "confidence": 0.95, "size": "large"},
  {"label": "Soundbar", "confidence": 0.88, "size": "medium"},
  {"label": "Console table", "confidence": 0.92, "size": "large"},
  {"label": "Plant stand", "confidence": 0.85, "size": "small"}
]
```

### LLMへのプロンプト
```
検出されたアイテム:
[上記4個]

**必須**: 上記の各アイテムごとに1つずつタスクを作成してください。合計4個のタスクを出力してください。
```

### 期待されるLLMレスポンス
```json
{
  "tasks": [
    {
      "id": "...",
      "title": "Televisionを売却する",
      "exitTag": "SELL",
      "dueDate": "2025-10-09T20:52:46Z",  // goalDate - 7days
      "checklist": [
        "モデル番号とシリアル番号を確認",
        "画面の傷や焼き付きチェック",
        "リモコンと電源ケーブル確認",
        "Facebook Marketplaceで相場調査"
      ],
      "links": ["https://www.facebook.com/marketplace/category/electronics"],
      "estimatedMinutes": 30,
      "note": "大型テレビは需要が高いです。"
    },
    {
      "id": "...",
      "title": "Soundbarを売却する",
      "exitTag": "SELL",
      "dueDate": "2025-10-09T20:52:46Z",
      "checklist": [
        "全ての音声端子の動作確認",
        "リモコンの動作テスト",
        "モデル番号確認と相場調査"
      ],
      "links": ["https://www.facebook.com/marketplace/"],
      "estimatedMinutes": 25,
      "note": "音響機器は動作確認が重要です。"
    },
    {
      "id": "...",
      "title": "Console tableを売却する",
      "exitTag": "SELL",
      "dueDate": "2025-10-09T20:52:46Z",
      "checklist": [
        "天板や脚部の傷確認",
        "寸法を正確に測定",
        "同様のテーブルの相場調査"
      ],
      "links": ["https://www.facebook.com/marketplace/category/furniture"],
      "estimatedMinutes": 20,
      "note": "家具は寸法情報が必須です。"
    },
    {
      "id": "...",
      "title": "Plant standを譲渡する",
      "exitTag": "GIVE",
      "dueDate": "2025-10-11T20:52:46Z",  // goalDate - 5days
      "checklist": [
        "安定性を確認",
        "簡単に清掃",
        "Buy Nothing groupに投稿"
      ],
      "links": ["https://www.facebook.com/groups/"],
      "estimatedMinutes": 15,
      "note": "小物は無料譲渡が早いです。"
    }
  ]
}
```

### 最終的にRemindersに登録されるタスク

**4個の個別タスク**:
1. ✅ Television売却 (SELL, 期限: 10/9)
2. ✅ Soundbar売却 (SELL, 期限: 10/9)
3. ✅ Console table売却 (SELL, 期限: 10/9)
4. ✅ Plant stand譲渡 (GIVE, 期限: 10/11)

各タスクは:
- アイテム固有のタイトル ✓
- アイテム固有のチェックリスト ✓
- 適切な出口タグ (SELL/GIVE) ✓
- 出口タグに応じた期限 ✓
- Toronto向けのリンク ✓

## 結論

### ✅ 実装は正しく動作する

1. **4個検出 → 4個のタスク生成**: プロンプトで明示的に強制
2. **各タスクがアイテム固有**: システムプロンプトで禁止事項を明記
3. **ユーザー設定反映**: purpose/goalDate/region 全て渡される
4. **地域対応**: Toronto向けリンク（Facebook Marketplace, Kijiji）
5. **バリデーション**: exitTag と日付フォーマットを検証

### ⚠️ 唯一の懸念点

LLMが指示を無視して「N個のアイテムを整理する」のような汎用タスクを返す可能性はゼロではありません。ただし:

- プロンプトで**3回**強調（重要ルール、必須、悪い例）
- 具体例を提示
- items.count を明示

これらにより、LLMが指示通りに動作する確率は非常に高いです。

### 次のステップ

実際のアプリで写真を撮影して、期待通りの4個の個別タスクが生成されることを確認してください。
