# Spec-Driven Development Workflow / スペック駆動開発ワークフロー

Spec-driven development in this repository ensures every change moves from idea to implementation through five explicit checkpoints. This guide explains the flow, required assets, and Codex CLI practices so contributors and Claude Code stay aligned.

## Overview / 概要
- Purpose / 目的: Provide a reusable process for defining, designing, and shipping features with clear approvals.
- Scope / 対象: Applies to all work tracked under `.cckiro/specs/` and executed with Claude Code in the Codex CLI.
- References / 参考: See `agent.md` for operational rules (minimal change, safety, transparency).

## Five Phases / フェーズ
Each phase produces a markdown artifact stored in the spec directory. Update the approval block at the end of every document when reviewers sign off.

### Phase 0 – Preparation / フェーズ0 事前準備
- Purpose: Establish working directory and identify spec slug.
- Inputs: Task overview from user, CLI access.
- Activities:
  - Run `mkdir -p ./.cckiro/specs` if not existing.
  - Choose `<slug>` following naming rules (see below).
  - Create spec folder `.cckiro/specs/<slug>/`.
  - Copy templates and rename to final filenames.
- Output: Empty `requirements.md`, `design.md`, `implementation-plan.md` with front matter ready.

### Phase 1 – Requirements / フェーズ1 要件
- Purpose: Define problem, goals, FR/NFR, acceptance criteria.
- Inputs: User brief, preparation assets.
- Activities:
  - Fill front matter fields (title, slug, owner, dates).
  - Capture goals, scope, stakeholders, FR-*, NFR-*.
  - Enumerate acceptance criteria (AC-*) referencing FR/NFR.
  - Record risks, dependencies, open questions.
  - Use Codex CLI `update_plan` to track tasks; follow `agent.md` viewing/editing rules.
- Output: `requirements.md` complete and reviewed.
- Approval: Update `Decision` to `Approved` with date once reviewers confirm.

### Phase 2 – Design / フェーズ2 設計
- Purpose: Translate requirements into architecture, data contracts, and UX considerations.
- Inputs: Approved requirements.
- Activities:
  - Reference FR-*/AC-* within design sections.
  - Document components, data flow, prompt strategy, error handling.
  - Outline testing approach at design level.
  - Capture risks, alternatives, and open questions.
- Output: `design.md` capturing agreed solution.
- Approval: Reviewers mark `Decision: Approved` with date.

### Phase 3 – Implementation Plan / フェーズ3 実装計画
- Purpose: Build actionable plan to execute design safely.
- Inputs: Approved design.
- Activities:
  - Create WBS with task IDs (T1, T2, ...), owners, estimates.
  - Document sequencing, tooling, testing matrix, rollout/rollback steps.
  - Map tasks/tests to acceptance criteria.
- Output: `implementation-plan.md` ready for execution.
- Approval: Reviewers mark `Decision: Approved` with date.

### Phase 4 – Implementation / フェーズ4 実装
- Purpose: Carry out the plan using Codex CLI or manual development.
- Inputs: Approved implementation plan.
- Activities:
  - Execute tasks in order; keep `update_plan` synced.
  - Run agreed tests; capture results for reviewers.
  - Raise deviations via comments and update spec docs if scope changes.
- Output: Code changes, documentation, and validation evidence.
- Approval: Conduct final review (e.g., PR) referencing spec path.

## Phase Gates / フェーズゲート
Use these Definition-of-Done checklists to validate each phase.

- **Phase 1 Requirements DoD**
  - [ ] Problem, goals, metrics documented
  - [ ] `FR-*` and `NFR-*` numbered sequentially
  - [ ] `AC-*` enforceable and mapped to FRs/NFRs
  - [ ] `Approval` block shows `Decision: Approved`

- **Phase 2 Design DoD**
  - [ ] Architecture/workflow description covers every FR
  - [ ] Data contracts and error cases captured
  - [ ] Prompt strategy and safeguards defined (if applicable)
  - [ ] Risks/alternatives listed with rationale
  - [ ] `Approval` block shows `Decision: Approved`

- **Phase 3 Implementation Plan DoD**
  - [ ] WBS with owners and estimates
  - [ ] Testing strategy (unit/integration/manual) aligned to AC
  - [ ] Rollout, monitoring, rollback documented
  - [ ] Acceptance alignment section filled
  - [ ] `Approval` block shows `Decision: Approved`

## Directory & Naming Rules / 命名規約
- Base path: `.cckiro/specs/`
- Each spec resides in `.cckiro/specs/<slug>/`
- `<slug>` requirements:
  - lowercase kebab-case using ASCII `[a-z0-9-]`
  - starts with a letter, maximum 30 characters
  - no spaces, underscores, consecutive hyphens, or reserved names (`spec-driven-development`, `templates`)
- Valid examples: `tatsutori-mvp-enhancement`, `ios-reminders-export`
- Invalid examples: `MVP Spec` (space), `2025_cleanup` (starts with digit), `feature__xyz` (underscores)
- Required files inside each spec: `requirements.md`, `design.md`, `implementation-plan.md`

## Using Templates / テンプレ利用
1. Copy base templates: `.cckiro/specs/spec-driven-development/templates/*-template.md`
2. Paste into the new spec directory: `.cckiro/specs/<slug>/`
3. Rename files immediately:
   - `requirements-template.md` → `requirements.md`
   - `design-template.md` → `design.md`
   - `implementation-plan-template.md` → `implementation-plan.md`
4. Update front matter fields and ensure bilingual headings remain.
5. Keep approval block at bottom of each document; reviewers set decision and date.

### Template Metadata / テンプレメタデータ
- Always include numbered IDs (`FR-1`, `AC-1`, `T1`, etc.) to ease traceability.
- Cross-reference IDs between documents (e.g., design describes how it satisfies FR-1, plan lists tasks covering AC-1).

## Codex CLI Quick Start / CLI クイックスタート
```bash
# create spec directory (replace slug)
mkdir -p .cckiro/specs/tatsutori-mvp-enhancement
# copy templates
cp .cckiro/specs/spec-driven-development/templates/*-template.md \
   .cckiro/specs/tatsutori-mvp-enhancement/
# rename templates to final filenames
pushd .cckiro/specs/tatsutori-mvp-enhancement
for f in *-template.md; do mv "$f" "${f/-template/}"; done
popd

# collaborate via Codex CLI
codex update_plan .cckiro/specs/tatsutori-mvp-enhancement/requirements.md
codex update_plan .cckiro/specs/tatsutori-mvp-enhancement/design.md
codex update_plan .cckiro/specs/tatsutori-mvp-enhancement/implementation-plan.md
```
- Follow `agent.md` policies: prefer `rg` for search, avoid destructive commands, keep changes minimal.
- Record deviations or approvals directly in the spec documents.

## MVP Example / MVP具体例
Use the TatsuTori photo-to-reminder pipeline as a reference when drafting new specs.

1. **Photo Capture**: User snaps living room photo with TV, cables, books.
2. **Object Split**: Vision model annotates separate items (TV, cables bundle, book stack) respecting user mode (e.g., "sell-first").
3. **Intent Adjustment**: Spec documents how settings influence task granularity (e.g., combine small decor into one task, prioritize high-value items).
4. **Exit Plan**: Requirements enumerate FRs for generating exit tags (SELL/GIVE/RECYCLE/TRASH/KEEP).
5. **WBS Scheduling**: Implementation plan defines due date offsets from goal (`move_out_date`):

   | Exit Tag | Due Date Calculation | Notes |
   | --- | --- | --- |
   | SELL | move_out_date - 7d | include listing + pickup buffer |
   | GIVE | move_out_date - 5d | ensure contact outreach |
   | RECYCLE | move_out_date - 3d | add local depot search link |
   | TRASH | move_out_date - 2d | confirm municipal pickup rules |
   | KEEP | move_out_date - 1d | pack and label kept items |

6. **Reminders Export**: Design + plan describe creating tasks with exit tag in title, checklist steps, URLs, and due dates per offset.

## Best Practices / ベストプラクティス
- Minimal Change / 最小変更: Follow repo principle—touch only what is necessary.
- Transparency / 透明性: Announce intent before major edits; use `update_plan` diligently.
- Safety / 安全性: Observe sandbox rules, avoid destructive commands, never commit secrets.
- Traceability / トレーサビリティ: Keep IDs consistent across requirements, design, and plan.
- Collaboration / 協調: Use approval block to record decisions; mention reviewers in PR descriptions.

## Quick Start Checklist / クイックスタートチェック
- [ ] Create `.cckiro/specs/<slug>/` using naming rules
- [ ] Copy and rename templates to final filenames
- [ ] Fill front matter and bilingual headings in all documents
- [ ] Complete Phase 1 requirements and obtain approval
- [ ] Complete Phase 2 design and obtain approval
- [ ] Complete Phase 3 implementation plan and obtain approval
- [ ] Execute implementation with references to spec in PR/commit descriptions

## References / 参考資料
- `agent.md` – Codex CLI operations & safety rules
- `README.md` – Project overview and development info
- Existing specs under `.cckiro/specs/` for examples

## Approval / 承認
- Reviewer(s): @owner, @reviewer
- Decision: Pending
- Date: YYYY-MM-DD
