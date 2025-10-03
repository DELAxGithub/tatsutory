# テストプロンプト出力

## 想定される検出アイテム（RemoteDetectionServiceから）

```json
[
  {"label": "Television", "confidence": 0.95, "size": "large"},
  {"label": "Soundbar", "confidence": 0.88, "size": "medium"},
  {"label": "Console table", "confidence": 0.92, "size": "large"},
  {"label": "Plant stand", "confidence": 0.85, "size": "small"},
  {"label": "Decorative items", "confidence": 0.78, "size": "small"}
]
```

## 実際に送信されるプロンプト

### System Prompt
```
あなたは片付けの専門家です。検出された各アイテムについて、必ず1アイテム=1タスクで、具体的で実行可能な処分タスクを作成してください。

**重要ルール**:
- 検出されたアイテム数と同じ数のタスクを必ず作成する（5個検出されたら5個のタスク）
- 各タスクは1つのアイテムに特化した内容にする
- 「複数アイテムをまとめて」のような表現は禁止

各タスクで行うこと:
1. そのアイテムに最適な処分方法を決定（SELL/GIVE/RECYCLE/TRASH/KEEP）
2. ゴール日から逆算した現実的な期限を設定
3. そのアイテム固有の具体的なチェックリストを作成（3-5項目）
4. 地域に合った関連リンクを含める

ユーザーの優先事項に合わせて:
- 「価値ある物を売って手放したい」→ 売却可能なものは積極的にSELL、相場調査を含める
- 「とにかく早く片付けたい」→ GIVE/RECYCLEを優先、手間の少ない手順
- 「身の回りを整理整頓したい」→ バランスよく判断

出力は指定されたJSONスキーマに完全準拠してください。
```

### User Prompt
```
検出されたアイテム:
[
  {"label": "Television", "confidence": 0.95, "size": "large"},
  {"label": "Soundbar", "confidence": 0.88, "size": "medium"},
  {"label": "Console table", "confidence": 0.92, "size": "large"},
  {"label": "Plant stand", "confidence": 0.85, "size": "small"},
  {"label": "Decorative items", "confidence": 0.78, "size": "small"}
]

ユーザー設定:
- 引っ越し予定日: 2025-10-16T20:52:46Z
- 優先事項: 価値ある物を売って手放したい
- 地域: Toronto, CA

**必須**: 上記の各アイテムごとに1つずつタスクを作成してください。合計5個のタスクを出力してください。

良い例:
- Table（テーブル）→ タイトル「Tableをメルカリで売却」、チェックリスト: 「天板の傷を確認」「脚の安定性をチェック」「サイズを測定」
- Soundbar（サウンドバー）→ タイトル「Soundbarを売却」、チェックリスト: 「すべての端子が動作するか確認」「リモコンの動作確認」「モデル番号を調べて相場を確認」

悪い例:
- 「5個のアイテムを整理する」（これは禁止）
- 「家具をまとめて売却」（複数アイテムをまとめるのは禁止）
```

## 期待される出力（LLMからの応答）

```json
{
  "tasks": [
    {
      "id": "task-001",
      "title": "Televisionを売却する",
      "exitTag": "SELL",
      "dueDate": "2025-10-09T20:52:46Z",
      "checklist": [
        "テレビのモデル番号とシリアル番号を確認",
        "画面に傷や焼き付きがないかチェック",
        "リモコンと電源ケーブルが揃っているか確認",
        "Facebook MarketplaceとKijijiで同型の相場を調査",
        "正面・側面・背面の写真を撮影"
      ],
      "links": [
        "https://www.facebook.com/marketplace/category/electronics",
        "https://www.kijiji.ca/b-electronics/gta/c15l1700272"
      ],
      "estimatedMinutes": 30,
      "note": "大型テレビは需要が高いです。配送方法（引き取りのみ等）を明記すると売れやすいです。"
    },
    {
      "id": "task-002",
      "title": "Soundbarを売却する",
      "exitTag": "SELL",
      "dueDate": "2025-10-09T20:52:46Z",
      "checklist": [
        "すべての音声端子（HDMI, Optical等）が動作するか確認",
        "リモコンの動作確認とペアリングテスト",
        "モデル番号を確認し、最近の売却価格を調査",
        "サブウーファーやケーブル類が全て揃っているか確認",
        "正面・背面・端子部分の写真を撮影"
      ],
      "links": [
        "https://www.facebook.com/marketplace/category/electronics",
        "https://www.kijiji.ca/"
      ],
      "estimatedMinutes": 25,
      "note": "音響機器は動作確認が重要です。元箱があれば価値が上がります。"
    },
    {
      "id": "task-003",
      "title": "Console tableを売却する",
      "exitTag": "SELL",
      "dueDate": "2025-10-09T20:52:46Z",
      "checklist": [
        "天板や脚部に傷や破損がないか確認",
        "テーブルの寸法を正確に測定（幅×奥行×高さ）",
        "引き出しやシェルフの状態をチェック",
        "同様のコンソールテーブルの相場を調査",
        "全体・ディテール・収納部分の写真を撮影"
      ],
      "links": [
        "https://www.facebook.com/marketplace/category/furniture",
        "https://www.kijiji.ca/b-table-chairs/gta/c241l1700272"
      ],
      "estimatedMinutes": 20,
      "note": "家具は「引き取りのみ」とすると管理が楽です。寸法情報は必須です。"
    },
    {
      "id": "task-004",
      "title": "Plant standを譲渡する",
      "exitTag": "GIVE",
      "dueDate": "2025-10-11T20:52:46Z",
      "checklist": [
        "プラントスタンドの安定性を確認",
        "汚れや傷があれば簡単に清掃",
        "写真を撮影して状態を記録",
        "地域のBuy Nothing groupやFreecycleに投稿"
      ],
      "links": [
        "https://www.facebook.com/groups/",
        "https://www.freecycle.org/"
      ],
      "estimatedMinutes": 15,
      "note": "小物スタンドは無料で譲渡が早いです。引き取り日時を柔軟に設定しましょう。"
    },
    {
      "id": "task-005",
      "title": "Decorative itemsを整理する",
      "exitTag": "GIVE",
      "dueDate": "2025-10-11T20:52:46Z",
      "checklist": [
        "装飾品を種類別に分類（ガラス製品、陶器、プラスチック等）",
        "破損しているものは廃棄用に分ける",
        "状態の良いものをまとめて写真撮影",
        "地域のBuy Nothing groupに投稿"
      ],
      "links": [
        "https://www.facebook.com/groups/",
        "https://www.freecycle.org/"
      ],
      "estimatedMinutes": 20,
      "note": "装飾品は個別に売るより、まとめて譲渡の方が早く処分できます。"
    }
  ]
}
```

## 改善ポイント

現在の実装では:
- ✅ 5個のアイテム検出 → 5個のタスク生成
- ✅ 各タスクがアイテム固有の内容（Televisionなら「焼き付きチェック」、Soundbarなら「端子確認」）
- ✅ ユーザー優先事項を反映（価値あるものは SELL、小物は GIVE）
- ✅ 地域リンク（Toronto: Facebook Marketplace, Kijiji）
- ✅ 期限はゴール日から逆算（SELL: -7日、GIVE: -5日）

これが期待される動作です。
