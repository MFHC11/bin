---
name: lp-quarterly-report-skill
description: LP quarterly reporting moved from Claude cowork to claude code as a skill (2026-07-02); delta discipline is the core rule
metadata: 
  node_type: memory
  type: project
  originSessionId: 4bd4cd7f-c899-4a45-9df7-d6c1efd854d7
---

Marcus moved his ERV LP quarterly reporting workflow from Claude cowork
into the brain on 2026-07-02. Skill: ~/bin/skills/lp-quarterly-report/
(authoritative prompt ~/bin/prompts/lp-quarterly-report.md), codified from
the 11 historical reports and superseding the old cowork project
instruction set.

**Why:** The cowork set only covered the ERV Group Shareholder Update and
asked Marcus for raw notes. The brain now holds board packs, minutes and
emails, so the skill is brain-first, and the corpus showed the real
failure mode was stale repetition (Blixt X-Verter paragraph ran
near-verbatim 4 quarters).

**How to apply:** Any quarterly LP/board/shareholder report runs through
the skill. Non-negotiables: company entries target ~200 words, hard max
250-275 only when the detail is pertinent for investors (Marcus
calibration 2026-07-02, "maximise value per word"); read prior quarter's
entry first and close every loop it opened; genericise investors in live
unclosed rounds;
[CONFIRM: ] flags instead of fabrication; this genre REPORTS (includes
MOIC and distress), the opposite of [[lp-follow-up-email]] which sells;
[[centrica-anchor-confidential]] still applies. Q1 2026 reports live in
inbox/ docx; drafts go to drafts/lp-quarterly-reports/.
