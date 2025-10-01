---
title: Photo Multi Split v1 Requirements
slug: photo-multi-split-v1
owner: @tatsu-mobile
created: 2025-09-15
updated: 2025-09-15
status: Approved
---

# Requirements Specification / 要件定義

## Summary / 概要
- Goal / 目的: 1枚の写真から複数アイテムを抽出し、ユーザー意図とゴール日オフセットに基づく出口タスクを30秒以内でApple Remindersへ登録できるようにする。
- Context / 背景: MVPカメラフローを拡張し、単一写真でも複数アイテムを自動整理しつつ、意図モードとWBSロジックを連携させる第一弾アップデート。

## Goals & Success Metrics / 目標と成功指標
- G1: 高精度なマルチアイテム抽出でプレビュー編集工数を最小化する。
- G2: ユーザー意図とゴール日オフセットを自動反映し、手動調整を不要化する。
- G3: 30秒以内にエクスポート完了するレスポンスを維持する。
- Metrics / 指標:
  - 抽出数の実数±1一致率 ≥ 80%
  - プレビューでの不要タスクOFF率 < 20%
  - P50レイテンシ ≤ 5s / P95 ≤ 10s（撮影→プレビュー）
  - E2E（撮影→Reminders登録完了）P95 ≤ 30s
  - Remindersエクスポート成功率 ≥ 95%

## Schedule / スケジュール
- 設計レビュー完了: 2025-10-07
- 実装完了（photo_multi_splitフラグONで検証開始）: 2025-10-21

## Scope / 対象範囲
- In Scope / 対象:
  - 単一写真から最大8件までのアイテム検出（デフォルトで小物除外）
  - 意図モード（引っ越し/終活 + 売る優先/早く処分）による粒度・出口方針調整
  - move_out_dateに基づく期限逆算（SELL:-7 / GIVE:-5 / RECYCLE:-3 / TRASH:-2 / KEEP:-1）
  - プレビュー画面の全OFF→個別ON操作、個別トグルUI
  - Apple Remindersへの一括エクスポート（タイトル/ノート/期限 設定）
- Out of Scope / 非対象:
  - 価格推定、複数写真の統合、Todoist/Notion等の他プラットフォーム連携
  - 高負荷なオンデバイス学習や高度な画像編集
  - 地域ガイドの新規拡充（既存テンプレ参照のみ）

## Functional Requirements / 機能要件
- FR-1: 単一写真から最大8件のアイテム候補を検出し、バウンディングボックスとカテゴリラベルを付与する。
- FR-2: 意図モードに応じて小物や低価値アイテムを除外し、抽出結果を調整する。
- FR-3: move_out_dateを基準に出口タグごと（SELL/GIVE/RECYCLE/TRASH/KEEP）の期限オフセットを自動適用する。
- FR-4: プレビュー画面で「全OFF→必要だけON」が1アクションで可能となり、個別トグルでON/OFFを切り替えられる。
- FR-5: Apple Remindersへタイトル・ノート・期限を含むタスクとして一括エクスポートできる。

## Non-Functional Requirements / 非機能要件
- NFR-1: 撮影→プレビュー表示のレイテンシがP50 ≤ 5s, P95 ≤ 10s。
- NFR-2: 撮影→Reminders登録完了までのE2EがP95 ≤ 30s。
- NFR-3: 初回エクスポート成功率が95%以上。
- NFR-4: 検証写真セットで抽出数±1一致率 ≥ 80%、主要ラベル正答率 ≥ 80%。
- NFR-5: 初回同意UIでデータ送信可否を取得し、拒否時はオフラインFallback（汎用タスク＋期限=goal-3d）を提供する。

## SLO & Constraints / SLO・制約
- プライバシ: 既定で端末内保持。送信時はサムネイル圧縮を優先し、明示同意時のみAPIへ送信。
- モデル制約: CoreML/軽量YOLO or Vision+LLM補助のいずれかを採用し、モデルサイズはアプリバンドル基準を満たす。
- デバイス: iOS 17+、iPhone 12相当以上をターゲット。

## Deliverables / 成果物
- D1: マルチアイテム検出サービスと意図モード対応フィルタの実装。
- D2: プレビューUIの全OFF/個別トグル機能と小物除外設定。
- D3: ゴール日オフセットを反映したRemindersエクスポート実装とノート整備。
- D4: テレメトリ（レイテンシ、削除率、エクスポート結果）収集の計測ポイント追加。
- D5: QAチェックリストと検証データセット（50枚）に対する結果レポート。

## Acceptance Criteria / 受け入れ基準
- AC-1（抽出品質・FR-1, FR-2, NFR-4）: 検証用50枚の写真で、プレビュー抽出数が実数の±1に収まる割合が80%以上、家具/家電/大型雑貨の主要ラベル正答率が80%以上。
- AC-2（意図&WBS・FR-3）: move_out_date基準でSELL:-7d / GIVE:-5d / RECYCLE:-3d / TRASH:-2d / KEEP:-1dの期限がReminders締切に反映される。
- AC-3（UX・FR-4）: プレビューで「全OFF→必要だけON」が1アクションで行え、各アイテムの個別トグルが機能し、デフォルトで小物除外フィルタがONになっている。
- AC-4（性能・信頼性・FR-5, NFR-1〜3）: 撮影→プレビュー P50 ≤5s/P95 ≤10s、撮影→Reminders P95 ≤30s、エクスポート成功率 ≥95%、失敗時は部分結果表示と再試行案内が提示される。
- AC-5（プライバシ・Fallback・NFR-5）: 初回にデータ送信の同意UIが表示され、拒否時にはLLMなしのFallbackで汎用タスク（期限=goal-3d）が生成・エクスポート可能。

## Assumptions / 前提条件
- オンボーディングまたは設定でユーザー意図モードが保存済みである。
- Vision/LLM APIの利用枠がSLO内で確保されている。
- Reminders権限が取得済みである。

## Dependencies / 依存関係
- 物体検出モデル選定およびアプリ同梱またはAPIアクセス。
- OpenAI等のLLM/APIレイテンシと利用枠。
- Apple Reminders APIのバッチ制限とフィールド仕様。

## Risks & Mitigations / リスクと軽減策
- R1: 過分割/誤検出 → 最大8件上限、小物除外、±1許容AC、プレビュー速操作で緩和。
- R2: レイテンシ増大 → 画像リサイズ、並列処理、LLMタイムアウト8s、部分結果提示。
- R3: エクスポート失敗 → リトライ処理、失敗ログ収集、キルスイッチで段階停止可能。
- R4: 同意フローでの離脱 → 初回1画面で完結、後から設定で変更可能にする。

## Open Questions / 未解決事項
- Q1: 同意OFF時のFallbackタスク内容（カテゴリ別テンプレ）はどこまで詳細化するか？
- Q2: 意図モードごとに小物除外閾値を変動させるか？

## References / 参考資料
- `./.cckiro/specs/spec-driven-development/workflow.md`
- Progress.md, ROADMAP.md

## Approval / 承認
- Reviewer(s): @codex, @po, @qa-lead
- Decision: Approved
- Date: 2025-09-15
