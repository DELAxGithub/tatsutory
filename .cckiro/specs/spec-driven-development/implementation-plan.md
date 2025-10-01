---
title: Spec-Driven Development Workflow Implementation
slug: spec-driven-development
owner: @codex
created: 2025-09-15
updated: 2025-09-15
status: Approved
---

## Work Breakdown Structure / 作業分解
1. **Template Assets (T1)**
   - Create `templates/requirements-template.md`
   - Create `templates/design-template.md`
   - Create `templates/implementation-plan-template.md`
   - Ensure front matter, numbered sections, approval block, bilingual headings
2. **Workflow Guide (T2)**
   - Author `workflow.md` following design outline
   - Include CLI quick start, phase gates, naming rules, MVP example, checklists
3. **Repo Integration (T3)**
   - Add quick reference in `README.md` (Development section) linking to workflow guide
   - Optionally note in `agent.md` if alignment needed
4. **Validation (T4)**
   - Self-review against acceptance criteria
   - Request user sign-off

## Sequencing / 手順
- Execute T1 → T2 → T3 in order (templates needed before referencing in guide)
- Perform T4 after drafts ready

## Tooling & Commands / ツール
- Use `mkdir -p` to create `templates/`
- Use `cat <<'EOF' > file` pattern for writing Markdown templates (ASCII)
- Follow repo `agent.md` guidelines; no git operations

## Testing Strategy / テスト方針
- Manual inspection: ensure placeholder IDs (FR-*, AC-*) present
- Verify command snippets are syntactically correct (dry-run reasoning)
- Confirm bilingual headings follow policy in each file

## Risk & Mitigation
- **Overlong docs** → keep sections concise, use bullet lists
- **Template misuse** → embed clear instructions and warnings in templates
- **Broken links** → double-check relative paths to templates and guide

## Rollback / Contingency
- If documentation proves confusing, revert to previous version (user directed) or iterate with additional examples

## Acceptance Traceability
- T1 maps to FR-2
- T2 maps to FR-1/3/4/5
- T3 supports discoverability (non-functional clarity)
- T4 ensures deliverables meet Acceptance Criteria

## Approval / 承認
- Reviewer(s): @hiroshikodera
- Decision: Approved
- Date: 2025-09-15
