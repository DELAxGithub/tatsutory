---
title: Spec-Driven Development Workflow Design
slug: spec-driven-development
owner: @codex
created: 2025-09-15
updated: 2025-09-15
status: Approved
---

# Spec-Driven Development Design

## Overview / 概要
Define repository assets enabling Claude Code–driven spec development: structure, templates, workflow guide, and supporting examples that satisfy the agreed requirements review.

## Directory & Naming Rules / 命名規約
- Base directory: `.cckiro/specs/`
- New spec path: `.cckiro/specs/<slug>/`
- `<slug>` requirements:
  - lowercase kebab-case, ASCII `[a-z0-9-]`
  - starts with a letter, max 30 characters
  - no spaces, underscores, double hyphens, or reserved names (`spec-driven-development`, `templates`)
- Inside each spec directory, final file names are fixed: `requirements.md`, `design.md`, `implementation-plan.md`
- Provide examples (`tatsutori-mvp-enhancement`, `ios-reminders-export`) and counterexamples in workflow guide.

## Document Set / ドキュメント構成
- `workflow.md`: primary guide covering five phases, gate definitions, and repo rules.
- `templates/requirements-template.md`, `templates/design-template.md`, `templates/implementation-plan-template.md`: source templates.
- Optional `examples/` directory housing one fully filled sample spec for newcomers (stretch goal noted for later phase if time allows).

## Template Specification / テンプレート設計
- Each template includes front matter block and approval section stub to enforce consistent metadata and gate stamping.
- Front matter fields:
  ```
  ---
  title: <SPEC TITLE>
  slug: <kebab-case-slug>
  owner: <handle>
  created: YYYY-MM-DD
  updated: YYYY-MM-DD
  status: Draft
  ---
  ```
- Mandatory approval block appended to every phase document:
  ```
  ## Approval / 承認
  - Reviewer(s): @owner, @reviewer
  - Decision: Pending | Approved | Changes Requested
  - Date: YYYY-MM-DD
  ```
- Requirements template prompts numbered IDs (e.g., `FR-1`, `NFR-1`, `AC-1`) with cross-reference hints for design/plan.
- Design template captures architecture, sequences, data contracts, prompt strategy, risks, mapping to FRs.
- Implementation plan template details WBS tasks, owners, estimates, tooling commands, testing matrix, rollout/rollback, and explicit linkage to acceptance criteria.

## Workflow Guide Outline / ワークフローガイド構成
Sections planned for `workflow.md`:
1. **Overview / 概要**: Purpose, why spec-driven approach suits TatsuTori.
2. **Five Phases / フェーズ**: For each phase include:
   - Purpose statement
   - Inputs (specific file paths)
   - Activities with CLI tips referencing `agent.md`
   - Exit criteria (Definition of Done checklist) and approval stamping instructions
3. **Phase Gates / フェーズゲート**: Consolidated checklists:
   - Phase 1 Requirements DoD
     - [ ] Problem, goals, metrics filled
     - [ ] `FR-*` and `NFR-*` numbered
     - [ ] Acceptance criteria `AC-*` testable
     - [ ] Approval = Approved
   - Phase 2 Design DoD
     - [ ] Architecture + sequence diagrams/description
     - [ ] Data contracts & error cases
     - [ ] Prompt strategy & safeguards
     - [ ] Risks/alternatives documented
     - [ ] Approval = Approved
   - Phase 3 Implementation Plan DoD
     - [ ] WBS with owners & estimates
     - [ ] Test plan (unit/integration/E2E)
     - [ ] Rollout & rollback steps
     - [ ] DoD aligns to AC
     - [ ] Approval = Approved
4. **Directory & Naming Rules / 命名規約**: Embed section above with examples and counterexamples.
5. **Using Templates / テンプレ利用**: Step-by-step instructions (copy, rename, fill front matter) and bilingual guidance.
6. **Codex CLI Quick Start**: Concrete command examples (see next section) and reminders about sandbox/approval rules.
7. **MVP Example**: Detailed walkthrough applying templates to the photo→split→intent→WBS→Reminders scenario, including offset table.
8. **Best Practices**: Safety, minimal changes, collaboration etiquette.
9. **Quick Start Checklist**: Printable list for PR authors.

## Codex CLI Quick Start / CLI 手順
Provide copy-ready command block:
```bash
# create spec directory
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
- Instruction note: always follow `agent.md` (safety, transparency, approvals) when issuing commands.

## MVP Example / MVP具体例
- Goal date variable: `move_out_date`
- Provide offset table to guide default due dates:

  | Exit Tag | Due date calculation | Notes |
  | --- | --- | --- |
  | SELL | `move_out_date - 7d` | allows 3-day pickup buffer |
  | GIVE | `move_out_date - 5d` | include contact outreach step |
  | RECYCLE | `move_out_date - 3d` | add local depot link |
  | TRASH | `move_out_date - 2d` | include municipal pickup schedule |
  | KEEP | `move_out_date - 1d` | confirm storage location and packing |

- Example narrative: photo with TV + books → object detection splits items → intent mode adjusts priority → tasks generated with offsets → batched into Reminders with exit tags and notes.

## Bilingual Headings Policy / 見出しルール
- Use format `## Title / 見出し` for major sections.
- English sentences first; append one-line Japanese summary or hint.
- Avoid duplicating full paragraphs in Japanese—use concise cues.
- Maintain ASCII markdown; Japanese text follows existing repository practice.

## Quick Start Checklist / クイックスタートチェック
- [ ] Create `.cckiro/specs/<slug>/` following naming rules
- [ ] Copy templates and rename to final filenames
- [ ] Populate front matter and bilingual headings
- [ ] Complete Phase 1 requirements and mark approval
- [ ] Complete Phase 2 design and mark approval
- [ ] Complete Phase 3 implementation plan and mark approval
- [ ] Reference spec path in PR description and link relevant issues

## Acceptance Mapping / 要件対応
- Functional requirements satisfied via:
  - Directory rules section (FR-1)
  - Templates with metadata + approval sections (FR-2)
  - Workflow guide outline + phase gates (FR-3)
  - CLI command block + `agent.md` references (FR-4)
  - MVP example offsets table (FR-5)
- Non-functional requirements met by bilingual conventions, concise markdown, repo rule alignment.

## Risks & Mitigations / リスクと対策
- Inconsistent adoption → mitigate with explicit naming rules, quick checklist, approval stamps.
- Template misuse (wrong filenames) → renaming step and warnings in guide.
- Process drift → enforce gates and cross-link to acceptance criteria/tracking.
- Future expansion (examples directory) → documented as optional to avoid scope creep now.

## Approval / 承認
- Reviewer(s): @hiroshikodera
- Decision: Approved
- Date: 2025-09-15
