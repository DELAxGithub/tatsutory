---
title: Photo Multi Split v1 Requirements
slug: photo-multi-split-v1
owner: @tatsu-mobile
created: 2025-09-15
updated: 2025-10-01
status: Approved
---

# Requirements Specification / 要件定義

## Summary / 概要
- Goal / 目的: Oct 2025 出荷向け TatsuTori MVP 完成ラインをここで確定し、実装と検証の終着点を共有する。
- Context / 背景: 「写真→AI分割→期限付きタスク→Reminders」までを一気通貫で提供し、意図設定と地域特化を武器とした初回リリースを成立させる。

## 1. コア体験（絶対必須）
- 単一画像入力（撮影 or ライブラリ）。
- GPT-5 mini Vision を利用し最大8件のアイテム JSON（`id`, `label`, `bbox`, `confidence`）を取得。
- Intent設定を参照し、WBSロジックで exit_tag・期限（goal_date + offset）・チェックリスト・地域リンクを確定。
- プレビューでタスクを確認し、個別に除外可能（全OFF→必要だけON対応）。
- Reminders へタイトル・ノート・期限（必要に応じてチェックリスト記載）付きで一括登録。
- 成果物は常に JSON schema 一致の状態で RemindersService へ渡す。

## 2. Intent設定（差別化の核）
- 初回アンケート＋Settingsで保持。
- 必須フィールド: Purpose（`move_fast` / `move_value` / `cleanup` / `legacy_hidden`）、Goal date（日付ピッカー）、Region（`JP` / `CA-TO` / `Other`）、Reminders list（既存選択 or 新規作成）。
- Advanced: 小物しきい値（`low` / `default` / `high`）、最大タスク数（≤8）、オフセット編集（初期値 SELL:-7, GIVE:-5, RECYCLE:-3, TRASH:-2, KEEP:-1）、LLM consent（Keychain保持）。
- 設定変更時は Telemetry で intent_changed を記録、legacy_hidden への切り替えは legacy_mode_enabled を記録。

## 3. 地域プリセット
- JP: 自治体ゴミ検索、メルカリ、ヤフオク、ジモティーリンク。
- CA-TO: Waste Wizard、e-waste ドロップオフ、Facebook Marketplace、Kijiji リンク。
- Other: 汎用的な整理術リンク（1件以上）。
- これらをタスクノート（もしくはチェックリストセクション）へ自動添付する。

## 4. Reminders 出力仕様
- タイトル形式: `<Item> [SELL|GIVE|RECYCLE|TRASH|KEEP]`。
- ノート: チェックリスト風手順（1行1項目）、地域リンク、参照URLの順で整理。不要情報は含めない。
- 期限: `goal_date + offset(exitTag)` を ISO8601 で設定。タイムゾーンは端末設定に従う。
- リスト: Intent設定で選択されたものを必須使用。必要に応じて自動作成。
- RemindersService は失敗時に部分コミットを残さずロールバックし、成功時のみ commit。

## 5. Fallback & 安定性
- consent=OFF または allowNetwork=false → ローカル汎用タスク1件（期限=goal_date-3d、KEEP想定）を生成。
- JSON schema 不一致や LLM 応答欠損 → 即座にローカル TaskComposer プランへフォールバック。
- 429 等レート制限 → planSource を `RATELIMIT` とし、ローカルプランを維持。
- どの経路でも Reminders には最低1件のタスクが登録される。

## 6. Telemetry 要件
- detector_route (`remote` / `local_fallback`)。
- detector_remote_status（`success` / `429` / `schema_invalid` / その他エラー内容）。
- detection_raw_count、detection_after_threshold_count（正規化後の件数とドロップ数含む）。
- intent_changed、legacy_mode_enabled。
- ai_enrichment_attempt/success/rate_limited/skipped。
- export_success/export_failure。
- perf_capture_to_preview_ms、perf_detect_ms_remote、必要なら perf_preview_to_export_ms。
- すべて DEBUG ではログ可視化、本番はバッチ送信対応。

## 7. 受け入れ基準（AC）
- AC-1: 10枚スモークテストで検出件数が ground truth の ±1 に収まる率 ≥ 80%。
- AC-2: Reminders 登録タスクの期限が Intent オフセット表に完全一致する。
- AC-3: Consent=OFF もしくはネット切断時に必ず Fallback タスク（期限=goal-3d）が生成される。
- AC-4: capture→preview P50 ≤ 5s / P95 ≤ 10s、export 成功率 ≥ 95%。
- AC-5: プレビュー画面の planSource バッジ（LOCAL / OPENAI / RATELIMIT）が状態に応じて変化。

## 完成とスコープ境界
- やる: リモート検出、Intent/WBS、地域プリセット、Reminders登録、Fallback、Telemetry、性能計測。
- やらない: 複数写真統合、価格推定、家族共有UI、Todoist/Notion連携。
- 隠し球: legacy_hidden モードはデバッグ設定で有効化可（一般公開は次フェーズ）。

## スケジュールとマイルストーン
- MVP仕様確定（本ドキュメント）: 2025-10-01。
- 実装完了 & QA 開始: 2025-10-21（feature flag `photo_multi_split` ON 環境で検証）。
- 出荷リハーサル: 2025-10-28。

## 指標と SLO
- 抽出精度: ±1一致率 ≥ 80%。
- レイテンシ: capture→preview P50 ≤ 5s / P95 ≤ 10s。capture→Reminders P95 ≤ 30s。
- 信頼性: Reminders export 成功率 ≥ 95%、失敗時はユーザーに再試行ガイダンス提供。
- プライバシ: 同意がない限り画像は端末外に送信しない。送信時は JPEG 圧縮＋payload 正規化。

## 依存関係と前提
- OpenAI GPT-5 mini Vision API キーと十分なクォータ。
- Apple Reminders 権限および EKEventStore フルアクセス。
- IntentSettingsStore による設定永続化（UserDefaults + Keychain）。
- LocaleGuide/RegionLinks の最新情報更新。

## リスクと軽減策
- R1: LLM 応答不整合 → JSON schema 強制、正規化後の Telemetry 記録、即座フォールバック。
- R2: レイテンシ超過 → 画像リサイズ、LLM タイムアウト 8s、capture→preview/perf ログで監視。
- R3: Reminders API 失敗 → コミット前に一括 save、失敗時 reset()、エラーテレメトリ送信。
- R4: Intent 設定不足 → 初回アンケート必須化、Settings で随時更新可能。

## Open Questions / 未解決事項
- Q1: `legacy_hidden` モードの UI 表示はデバッグ限定のままで良いか？公開時期を別途決定する必要あり。
- Q2: スモークテスト 10枚の ground truth 構築方法と担当。

## References / 参考資料
- `./.cckiro/specs/spec-driven-development/workflow.md`
- Progress.md, ROADMAP.md

## Approval / 承認
- Reviewer(s): @codex, @po, @qa-lead
- Decision: Approved
- Date: 2025-10-01
