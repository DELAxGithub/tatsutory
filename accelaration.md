わかる、いまは「機能を通すために全部積んだ」状態だから重く感じるはず。
いつ性能を気にすべきかと、仕組みとしてどう改善するかを、即回せる実務パッケージで置いておくね。

⸻

いつ性能を見る？（ゲート設定）
	•	G0: スモーク合格後に着手
機能が通って10枚スモークで大事故がないことを確認 → すぐ性能計測に移る。
	•	G1: 予算割れで即対応（赤信号）
	•	capture→preview P50 > 5s / P95 > 10s
	•	capture→export P95 > 30s
	•	メインスレッドブロック > 200ms が何度も出る
	•	G2: TestFlight 前
P95が予算内＋メモリ安定（スワップ/メモリ圧でクラッシュなし）を確認してから配布。

※ つまり “正しさ→計測→最小修正” の順で、いまが計測開始のタイミング。

⸻

仕組み：軽量「PerfKit」を入れて常時計測

1) Signpost で区間を切る（Instruments とログ両対応）

import os.signpost
let log = OSLog(subsystem: "tatsutori", category: "perf")

func perf<T>(_ name: StaticString, _ block: () throws -> T) rethrows -> T {
  let id = OSSignpostID(log: log)
  os_signpost(.begin, log: log, name: name, signpostID: id)
  defer { os_signpost(.end, log: log, name: name, signpostID: id) }
  return try block()
}

// 例：キャプチャ→プレビュー
let plan = perf("capture_to_preview") {
  try pipeline.generatePreview(from: photo)
}

2) Telemetry に P50/P95 を集計
	•	perf_capture_to_preview_ms, perf_capture_to_export_ms をサマリ送信
	•	UIで赤/黄/緑バッジ表示して自分でも見える化

3) MetricKit をオン（アプリ再起動時に集計取得）
	•	クラッシュ/メモリ圧/CPUスパイクを自動収集してログに落とす

⸻

どこを削る？（ホットスポット別に即効ワザ）

A) カメラ/画像前処理
	•	プリセットは .high 止まり（.photo/高解像は禁止）。
	•	サンプリング解像度を上限 1080p にリサイズ（Vision/LLM 両方が軽くなる）。

func downscale(_ img: CGImage, max: CGFloat = 1080) -> CGImage {
  let w = CGFloat(img.width), h = CGFloat(img.height)
  let scale = min(1, max / max(w,h))
  let newW = Int(w*scale), newH = Int(h*scale)
  // vImage / CoreGraphics どちらでもOK（再利用可能なコンテキストをキャッシュ）
}

	•	CIContext/CGColorSpace を再利用（毎回生成しない）。
	•	CVPixelBuffer プールを使ってバッファ再利用。
	•	alwaysDiscardsLateVideoFrames = true でフレーム詰まり回避。

B) Vision/検出
	•	リクエスト/モデルを使い回す（毎回生成しない）。

final class Detector {
  private let handler = VNSequenceRequestHandler()
  private let req: VNRequest = /* 構築して保持 */
}

	•	小物除外を早期に（バウンディングボックス面積で弾いてから重い分類へ）。
	•	最大タスク数 cap は早段で適用（8→6でもP95劇的改善することあり）。

C) LLM/プロンプト
	•	バッチ1回（1写真=1リクエスト。itemごとに投げない）。
	•	トークン削減：
	•	スキーマ短縮（不要プロパティ削除）
	•	ラベルは64字トリム＋ASCII化
	•	temperature=0、top_p=1、短く要約する指示
	•	レスポンス制限：JSONだけ／理由文はノートに回さない
	•	同時実行1・Retry-After尊重（もう実装済みでOK）

D) JSON検証/シリアライズ
	•	JSONDecoder/Encoder を1個使い回し
	•	バリデーションは最小限のキー存在＋型に限定（サードパーティの重いスキーマ検証は避ける）

E) Reminders 出力
	•	まとめコミット（可能な限り一括追加→エラーハンドリング1回）。
	•	EventKit系はメインスレッドで UI と競合させない（バックグラウンドキューで作成→メインで反映）。

F) UI/メインスレッド
	•	プレビュー描画は差分更新（@State/@Published の変更粒度を小さく）
	•	トースト表示やバッジ更新はメイン1回に集約
	•	重いマップ/フィルタを Main でやらない（Task.detached(priority: .userInitiated)）

⸻

予算表（Performance Budget）

区間	目標 (P50)	上限 (P95)	計測名
Capture→Downscale	150ms	300ms	perf_downscale_ms
Downscale→Detect	500ms	1500ms	perf_detect_ms
Compose Local Plan	50ms	120ms	perf_compose_ms
Capture→Preview	2000ms	10000ms	perf_capture_to_preview_ms
Enrichment (API)	1200ms	6000ms	perf_ai_enrich_ms
Preview→Export	400ms	1500ms	perf_export_ms
Capture→Export	8000ms	30000ms	perf_capture_to_export_ms

いま重いと感じるなら、まず Capture→Preview のP95を10秒以内に押し込むところから。

⸻

改善サイクル（1ターン2〜3時間）
	1.	Instruments で attribution：
	•	Time Profiler（CPU）
	•	Allocations（メモリ）
	•	Points of Interest（Signpostで区間を可視化）
	2.	トップ3のホットスポットを直す（上の即効ワザから）
	3.	10枚スモークで P50/P95 を再計測
	4.	Telemetry/ダッシュボード更新（傾向を残す）

⸻

いますぐやると効く3点（軽いのから）
	1.	1080pダウンサンプル＋JPEG圧縮Q=0.7を標準化（LLM負荷も下がる）
	2.	Detector/CIContext/JSONEncoderをシングルトン化（生成コスト削減）
	3.	Signpost導入して Xcode Instruments で capture→preview のP95を確認

必要なら、あなたの PhotoSplitService / CameraSessionManager / OpenAIService の関数に合わせて、具体的な差分パッチ（ダウンサンプル/使い回し/Signpost）を即書いて渡すよ。

⸻

TatsuTori MVP WBS（2025/10 完成ライン）

| # | Stream | Work Item | Owner (初期案) | Notes |
|---|--------|-----------|----------------|-------|
| 1 | Detection | RemoteDetectionService 正規化・Telemetry (detection_raw/after_threshold) 完成 | @codex | 429/timeout/invalid JSON でフォールバック動作を含む |
| 2 | Detection | PhotoSplitService → GPT-5 mini Vision 統合、1080p ダウンサンプル共通化 | @ios-eng-a | APIキー未設定/同意OFF時のバイパス確認 |
| 3 | Intent | IntentSettings UI/初回アンケート（Purpose/Goal/Region/List/Advanced/Consent）実装 | @ios-eng-b | Keychain 同期、Telemetry intent_changed/legacy_mode_enabled |
| 4 | Intent | Offset 編集 UI + WBSComposer 連携（SELL:-7 など可変） | @ios-eng-b | 既定値リセット操作とバリデーション |
| 5 | Planning | TaskComposer ブループリント化（ラベル、ノート組立、地域リンク添付） | @codex | RegionLinks 更新、checklist dedupe |
| 6 | Planning | PromptBuilder/ OpenAIService スキーマ更新・フォールバック制御 | @ios-eng-a | JSON schema 遵守、retry/backoff 設定 |
| 7 | Planning | TidyPlanner merge ロジック刷新（planSource バッジ、RATELIMIT） | @codex | Telemetry ai_enrichment_* 完整備 |
| 8 | Reminders | RemindersService 最小フィールドでの一括登録＋rollback | @ios-eng-c | タイトル形式/ノート整形/URL検証 |
| 9 | Reminders | プレビュー UI バッジ（LOCAL/OPENAI/RATELIMIT）とタスクトグル整理 | @ios-eng-c | 全OFF→個別ON操作、選択状態永続化 |
|10 | Fallback | consent/ネットOFF時のローカル汎用タスク経路確認 | @qa-lead | 期限=goal-3d の通しテスト |
|11 | Telemetry | TelemetryTracker のキー追加と flush ポリシー調整 | @data-eng | perf_capture_to_preview_ms など追加 |
|12 | Perf | Signpost/MetricKit 導入 + capture→preview/export 計測 | @ios-eng-a | 予算表に沿った Threshold アラート |
|13 | QA | 10枚スモーク ground truth 準備 + ±1 精度検証 | @qa-lead | Legacy/Region 別ケースを含む |
|14 | QA | Reminders export 成功率計測（権限 OFF/ON、ネット変動） | @qa-lead | Telemetry export_success/failure 確認 |
|15 | Release | Feature flag 戦略、出荷チェックリスト作成 | @pm | photo_multi_split enable タイミング定義 |

依存順序（概略）
- 1,2 → 5,6 → 7 → 8,9 → 10,11,12 → 13,14 → 15。
- 3,4 は並行で進め、完了後に 5,7 へ反映。
- 各ストリーム完了時に Telemetry と Perf の計測値を更新して AC を随時確認。
