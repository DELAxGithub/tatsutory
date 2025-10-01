---
title: Photo Multi Split v1 Design
slug: photo-multi-split-v1
owner: @tatsu-mobile
created: 2025-09-15
updated: 2025-09-15
status: Approved
---

# Design Specification / 設計仕様

## Architecture Overview / アーキテクチャ概要
- Summary: Extend camera capture pipeline with a multi-item detection service, intent-aware filtering layer, and WBS-aware task composer feeding the existing planner and Reminders exporter.
- Context Diagram: Camera Capture → PhotoSplitService → IntentAdjuster → WBSComposer → PreviewViewModel → RemindersExporter.

## Key Decisions / 主要判断
- D1: Use on-device CoreML YOLOv8n variant for primary detection with optional cloud fallback when consented.
- D2: Represent detected items as `DetectedItem` models (id, bbox, label, confidence) to maintain separation between vision and planner layers.
- D3: Apply intent-mode rules via configurable thresholds table to avoid complex retraining.
- D4: Implement WBS offsets in the planner layer so downstream specs can reuse logic.

## Components & Responsibilities / コンポーネントと責務
| Component | Description | Related FR | Notes |
| --- | --- | --- | --- |
| `PhotoSplitService` | Runs detection model, returns up to 8 `DetectedItem`s with metadata | FR-1 | Includes downscaling + consent-aware API fallback |
| `IntentAdjuster` | Filters/merges items based on user mode (sell-first vs trash-first) | FR-2 | Applies size/value thresholds, optional heuristics |
| `WBSComposer` | Maps exit tags to due dates using goal date offsets | FR-3 | Shared utility returning `TaskSchedule` |
| `PreviewViewModel` | Manages toggle-all, per-item states, and small-item filter | FR-4 | Stores default filter state = ON |
| `RemindersExporter` | Builds title, notes, due date payloads and triggers EventKit import | FR-5 | Reuses existing service with new fields |
| `TelemetryTracker` | Records latency, removal rate, export success metrics | NFR-1..3 | Sends anonymized events (local log if offline) |

## Data & Contracts / データと契約
- Models / Schemas:
  - `DetectedItem`: `{ id: UUID, bbox: CGRect, label: String, confidence: Double, rawSize: CGSize }`
  - `AdjustedItem`: `DetectedItem` + `{ exitTag: ExitTag?, priorityScore: Double }`
  - `PhotoSplitResult`: `{ items: [AdjustedItem], processingTimeMs: Int, source: onDevice|cloud }`
  - `TaskSchedule`: `{ dueDate: Date, offsetDays: Int }`
- API / Interface Changes:
  - `TidyPlanner` to accept `[AdjustedItem]` and `moveOutDate`.
  - Preview view model to expose `toggleAllOff()` and `enableItem(id:)` functions.
- Error Handling / エラー処理:
  - Detection timeout (8s) triggers fallback to template task (single generic item).
  - Export errors bubble up as `ExportError` with user-friendly message + retry option.

## Workflow & Sequence / フローと順序
1. User confirms photo capture.
2. `PhotoSplitService` downsizes image (max 1024px) and runs CoreML detection; if consented cloud fallback needed, send thumbnail to API.
3. `IntentAdjuster` filters items (remove micro items if intent != "keep").
4. `TidyPlanner` assigns exit tags per AdjustedItem using existing rules.
5. `WBSComposer` calculates due dates relative to `move_out_date` per exit tag table.
6. `PreviewViewModel` initializes state: all items selected except small items (off). Provides toggle-all button to disable all, single tap to re-enable desired items.
7. On export, `RemindersExporter` builds tasks (title includes exit tag + label, notes include checklist, URLs) and writes via EventKit.
8. `TelemetryTracker` records timings and success/failure outcomes.

## Prompt Strategy / プロンプト戦略
- Inputs: Item labels, intent mode, locale context, exit tag hints.
- Guardrails: Limit prompt size by sending cropped thumbnails; include instruction to cap at 8 items; fallback to template when detection <1.
- The LLM is only used for label refinement when consented; otherwise rely on local label set.

## UX / UI Notes / ユーザー体験
- New "Toggle All Off" button at top of preview list (one tap).
- Each item displays thumbnail, exit tag suggestion, due date chip, per-item toggle.
- Default banner indicates "Small items filtered out" with option to re-include.
- Failure banner surfaces partial results and retry CTA when export fails.

## Dependencies / 依存関係
- CoreML YOLOv8n model packaged in app; optional remote detection API.
- Existing `move_out_date` stored in settings.
- EventKit permissions and calendar availability.

## Testing Strategy / テスト方針
- Unit: `PhotoSplitServiceTests`, `IntentAdjusterTests`, `WBSComposerTests` verifying offset table (SELL:-7 etc.).
- Integration: Simulate photo pipeline end-to-end with mock detection results, ensure Preview toggles and exporter operate.
- Manual: Run 50-photo validation set; measure latency and export success; verify consent flow and fallback.

## Risks & Mitigations / リスクと軽減策
- R1: Model false positives → curated dataset, confidence threshold 0.45, allow quick dismissal.
- R2: Cloud fallback latency → only use when consented and on Wi-Fi; otherwise degrade gracefully.
- R3: Reminders field limits → truncate notes at 512 chars, include essential checklist first.

## Alternatives / 代替案
- Option A: Cloud-only detection → simpler but privacy and latency concerns.
- Option B: Rule-based segmentation (color clustering) → low accuracy; rejected.

## Open Questions / 未解決事項
- Q1: Should we cache detection results to support undo/redo?
- Q2: Where to display telemetry opt-out controls?

## Acceptance Mapping / 要件トレーサビリティ
- FR-1 → `PhotoSplitService`, detection workflow.
- FR-2 → `IntentAdjuster`, threshold tables.
- FR-3 → `WBSComposer`, offset tests.
- FR-4 → `PreviewViewModel`, toggle UX design.
- FR-5 → `RemindersExporter` enhancements.
- AC-1..AC-5 addressed through testing strategy and UX notes.

## Approval / 承認
- Reviewer(s): @codex, @po, @qa-lead
- Decision: Approved
- Date: 2025-09-15
