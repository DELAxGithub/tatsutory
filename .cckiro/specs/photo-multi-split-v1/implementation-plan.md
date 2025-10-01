---
title: Photo Multi Split v1 Implementation Plan
slug: photo-multi-split-v1
owner: @tatsu-mobile
created: 2025-09-15
updated: 2025-09-15
status: Approved
---

# Implementation Plan / 実装計画

## Summary / サマリー
- Objective: Ship photo_multi_split feature flag delivering multi-item detection, intent-aware filtering, WBS scheduling, and Reminders export within 30s SLA.
- Related Docs: [requirements](./requirements.md), [design](./design.md)

## Work Breakdown Structure / 作業分解
| Task ID | Description | Owner | Estimate | Dependencies |
| --- | --- | --- | --- | --- |
| T1 | Integrate CoreML model & detection pipeline (`PhotoSplitService`) | @ml-dev | 3d | model asset ready |
| T2 | Implement intent-based filtering & thresholds (`IntentAdjuster`) | @tatsu-mobile | 2d | T1 |
| T3 | Add WBS offset module + unit tests (`WBSComposer`) | @planner-dev | 1.5d | T2 |
| T4 | Update preview UI for toggle-all/individual toggles | @ios-ui | 2d | T2 |
| T5 | Enhance Reminders exporter with new fields & fallback | @tatsu-mobile | 1.5d | T3 |
| T6 | Consent flow + offline fallback wiring | @ios-ui | 1.5d | T1 |
| T7 | Telemetry instrumentation (latency, removal, export outcomes) | @data-eng | 1d | T1-T5 |
| T8 | QA validation on 50-photo dataset + performance logging | @qa-lead | 3d | T1-T7 |
| T9 | Rollout prep: flag config, kill switch docs, monitoring alerts | @tatsu-mobile | 1d | T7 |

## Sequencing / 実施順序
1. T1 → T2 → T3 (core detection + intent + WBS)
2. Parallel: T4 & T6 once T2 ready; T5 after T3 complete.
3. T7 after functional pieces integrate.
4. T8 validation, followed by T9 rollout checklist.

## Resource Plan / 体制
- Contributors: @tatsu-mobile, @ml-dev, @ios-ui, @planner-dev, @data-eng
- Reviewers: @codex, @po, @qa-lead

## Tooling & Commands / ツールとコマンド
- Build/Test: `xcodebuild -scheme tatsutory -destination 'platform=iOS Simulator,name=iPhone 15' test`
- Model conversion: `coremltools` script (offline, doc TBD)
- Telemetry: use existing analytics client (`TelemetryTracker.log(event:)`)
- Note: Follow `agent.md` rules for Codex CLI interactions and sandbox safety.

## Testing & Validation / テストと検証
- Unit: Tests for detection parser, intent filter thresholds, WBS offsets equality (SELL:-7 etc.).
- Integration: Snapshot tests for preview toggles, export pipeline with mock EventKit.
- Performance: Instrument time stamps for P50/P95; run scripted capture session.
- Manual: QA executes 50-photo suite, records accuracy metrics, verifies consent fallback.

## Deployment & Rollout / デプロイ
- Feature flag `photo_multi_split` default OFF.
- Stage rollout: 10% → 50% → 100% per day pending telemetry (latency, crash, export failure metrics).
- Kill switch: Flip flag off, revert prompt via `prompt_version` configuration.

## Monitoring & Metrics / モニタリング
- Metrics: detection latency, preview removal rate, export failure rate.
- Collection Method: analytics events batched daily, QA dashboard updated weekly.

## Risk Log / リスクログ
- R1: Model size exceeds app limit → build script warns; fallback to server inference.
- R2: Reminders quota exceeded → throttle export to 40 tasks/run, surface error message.
- R3: Consent drop-off → A/B copy test, allow later opt-in via settings.

## Contingency / バックアウト
- Rollback Process: disable feature flag, revert to previous planner branch, purge cached model.
- Fallback Plan: default to single fallback task generation path (goal-3d) until issue resolved.

## Acceptance Alignment / 受け入れ整合性
- AC-1 covered by: T1, T2, T8 validation.
- AC-2 covered by: T3 unit tests + T8 verification.
- AC-3 covered by: T4 UI changes and QA manual checks.
- AC-4 covered by: T5 exporter, T7 telemetry, performance tests.
- AC-5 covered by: T6 consent flow & fallback tests.

## Open Items / 残課題
- Q1: Need final decision on per-intent threshold table values.
- Q2: Determine storage strategy for telemetry opt-out.

## Approval / 承認
- Reviewer(s): @codex, @po, @qa-lead
- Decision: Approved
- Date: 2025-09-15
