---
name: project_taste_index_system
description: "Taste Index built 2026-07-08 — gated store of Marcus's judgment; +taste trigger; hub concepts/taste-index, writing domain live; three-bucket routing"
metadata: 
  node_type: memory
  type: project
  originSessionId: 944fddb4-b52b-40c4-aa0b-68621d63140e
---

Marcus stood up a **Taste Index** on 2026-07-08 to store his judgment (what is good, why, what to avoid) separately from raw memory. Prompted by the "your AI agent needs taste, not memory" article; adapted to his stack rather than the article's generic Hermes+GBrain build because he already had proto-taste scattered across memory feedback files, skill prompts, and concepts pages, plus gbrain's native but empty `takes`/calibration system (takes_list, takes_scorecard, get_calibration_profile all returned empty on 2026-07-08).

**Structure (built):**
- Hub: `concepts/taste-index` (flat file `~/brain/concepts/taste-index.md`): explains the model, the capture shape, the gate, the domain register, the maintenance loop.
- First domain: `concepts/taste-writing`: consolidates voice, concrete-mechanism-over-ideology (the 2026-07-03 P2 ruling), benefit-led-not-spec-led descriptions, and AI-tell anti-patterns, drawn from [[feedback_article_taste_concrete]], [[feedback_erv_core_messaging]], [[reference_erv_portfolio_one_liners]], [[feedback_no_em_dashes]] and the article-persona skill.
- Capture skill: `~/bin/skills/taste-capture/SKILL.md`, trigger `+taste` / "save as taste" / `+anti`. Gated: no signal, no storage.
- Three-bucket routing by retrieval need: always-on cross-domain rules -> memory feedback (auto-loads via MEMORY.md); domain taste -> `concepts/taste-<domain>` read by that domain's skill; calibratable calls -> gbrain `takes` kind=bet (deferred, none logged yet).
- Wiring: `article-persona` now reads `concepts/taste-writing` before every draft; its inline "Marcus taste rulings" section became a pointer, so the taste page is the single source of truth. CLAUDE.md carries a "TASTE INDEX" section.

**Why:** memory records what happened; the taste index records what mattered and puts Marcus's judgment in front of skills at point-of-work. Selectivity is the design: the explicit `+taste` gate resists the brain's auto-ingestion gravity (2,831 orphans), so the dream cycle and daily may audit the index but must never author it.

**How to apply:** on `+taste`/`+anti`, run the taste-capture skill and route to the right bucket. Extend domains next: deals (investment judgment), lp-comms (current guide `concepts/erv-lp-comms-style-guide`), product/demo, design. When ready, start logging LP and market calls as gbrain bets so the calibration scorecard gets data. Related: [[project_weekly_article_system]], [[feedback_article_taste_concrete]], [[feedback_no_em_dashes]].
