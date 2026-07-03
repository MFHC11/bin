---
name: lp-quarterly-report
description: >
  Draft ERV quarterly LP/shareholder reports: the ERV Fund I Company Update
  (LP letter + per-company portfolio entries) and the ERV Group Shareholder
  Update (5-section format with performance dashboard). Codified 2026-07-02
  from the 11 historical reports (H2 2023 through Q1 2026), superseding the
  Claude cowork project instructions. Core discipline is DELTA REPORTING:
  read the prior quarter's entry first, lead with what changed, close every
  loop the prior quarter opened, never repeat stale facts. Brain-first data
  pipeline (company pages, board minutes, quarter emails) replaces asking
  Marcus for raw notes; gaps are flagged inline as [CONFIRM: ...], never
  fabricated. Candid register: runway cliffs dated, founder departures and
  down rounds reported plainly.
triggers:
  - "LP report"
  - "quarterly update" / "quarterly report" for Fund I or ERV Group
  - "company update Q<X>"
  - "shareholder update"
  - "portfolio update for LPs"
  - "draft the <company> entry for the quarterly"
  - any task producing ~/brain/inbox-style "ERV Fund I Company Update" or
    "ERV Group Shareholder Update" documents
mutating: true
writes_pages: false
writes_to:
  - drafts/lp-quarterly-reports/YYYY-MM-DD-q<X>-<year>-<scope>.md
sources_required:
  prior_reports:
    - the previous quarter's report (inbox/*.docx archive or projects/ page)
      is MANDATORY reading before drafting any entry
  brain_pages:
    - companies/<slug> for each company in scope (compiled truth, Key
      figures, Open Threads, Timeline)
    - projects/<company>-* raise/project pages if present
  meetings:
    - board minutes and meetings/* for each company within the quarter
    - inbox/* emails within the quarter mentioning the company
  recall:
    - recall(entity) per company for hot facts
cost_estimate: frontier session model (capital/LP analysis routes frontier per governor architecture)
model_default: frontier (Opus 4.8 / Fable 5)
authoritative_prompt: ~/bin/prompts/lp-quarterly-report.md  # read fresh each run
ledger: ~/brain/.tasks/skill-evolution/lp-quarterly-report/ledger.jsonl
---

# LP Quarterly Report skill

This SKILL.md is a router. The authoritative per-run instructions live in
`~/bin/prompts/lp-quarterly-report.md`, read fresh each run.

Hard rules that never bend:

1. Read the prior quarter's entry for every company before drafting.
2. Never fabricate a metric, valuation, round detail, cash position or
   runway date. Flag gaps inline as `[CONFIRM: ...]`.
3. Never name the Fund II anchor (Centrica, or any identifying form) in
   any report. "A FTSE 100 UK integrated energy company" is the phrasing.
4. No em dashes anywhere. En dashes in numeric ranges are fine.
5. Human-initiated only. No cron, no automation.
