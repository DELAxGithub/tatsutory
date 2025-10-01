---
title: Spec-Driven Development Workflow Requirements
slug: spec-driven-development
owner: @codex
created: 2025-09-15
updated: 2025-09-15
status: Approved
---

# Requirements Specification / 要件定義

## Summary / 概要
- Goal / 目的: Establish a repeatable spec-driven development workflow for TatsuTori using Claude Code.
- Context / 背景: Aligns repository practices with five-phase process (Preparation → Requirements → Design → Implementation Plan → Implementation).

## Goals & Success Metrics / 目標と成功指標
- G1: Provide canonical templates and checklists for all phases.
- G2: Document collaboration expectations between contributors and Claude Code.
- G3: Ensure workflow scales to upcoming MVP enhancements.
- Metrics / 指標: Adoption rate of spec workflow, reduction in review rework incidents.

## Stakeholders / ステークホルダー
- Product: @hiroshikodera
- Engineering: @codex
- Reviewer(s): @hiroshikodera

## Scope / 対象範囲
- In Scope / 対象: Repository documentation, template assets, workflow guidance, README cross-links.
- Out of Scope / 非対象: Implementing feature-specific code outside documentation/workflow assets.

## Functional Requirements / 機能要件
- FR-1: Define and document directory/naming conventions for `.cckiro/specs/`.
- FR-2: Provide Markdown templates for `requirements.md`, `design.md`, and `implementation-plan.md` with guidance.
- FR-3: Produce a workflow guide describing all five phases, handoffs, and approval checkpoints.
- FR-4: Document Codex CLI usage patterns referencing `agent.md` rules.
- FR-5: Include an MVP-aligned example demonstrating photo→split→intent→WBS→Reminder flow with due date offsets.

## Non-Functional Requirements / 非機能要件
- NFR-1: Documentation uses concise Markdown with ASCII characters unless existing files use Japanese text.
- NFR-2: Instructions remain actionable in both English and Japanese (bilingual headings or short summaries).
- NFR-3: Templates keep prompts minimal yet explicit to avoid over-specification.
- NFR-4: Guidance honors repository principles (minimal change, safety, transparency).

## Deliverables / 成果物
- D1: `workflow.md` summarizing spec-driven process and gate criteria.
- D2: Template Markdown files under `.cckiro/specs/spec-driven-development/templates/`.
- D3: Updated repository docs (e.g., README) referencing the workflow.

## Acceptance Criteria / 受け入れ基準
- AC-1 (covers FR-1, FR-3): Workflow guide documents naming rules, phase steps, and approval stamps.
- AC-2 (covers FR-2): Templates include front matter, approval blocks, bilingual headings, and numbering prompts.
- AC-3 (covers FR-4): Guide lists Codex CLI command examples and points to `agent.md`.
- AC-4 (covers FR-5): MVP example illustrates exit tag offsets and application of the workflow.
- AC-5 (covers NFR-1..4): Documentation remains concise, bilingual, and aligned with repository guidelines.

## Assumptions / 前提条件
- Contributors will continue using Codex CLI with existing sandbox policies.
- Reviewers are available to approve each phase document.

## Dependencies / 依存関係
- `agent.md` for operational rules.
- Existing planning artifacts (README, Progress, Roadmap) for context.

## Risks & Mitigations / リスクと軽減策
- R1: Overly complex templates → Mitigation: Use succinct instructions and comments only where necessary.
- R2: Low adoption → Mitigation: Reference workflow prominently in README/agent docs.

## Open Questions / 未解決事項
- Q1: Should future specs include automated linting for template compliance?

## References / 参考資料
- README.md, Progress.md, ROADMAP.md

## Approval / 承認
- Reviewer(s): @hiroshikodera
- Decision: Approved
- Date: 2025-09-15
