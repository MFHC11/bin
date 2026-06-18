---
name: portfolio-disclosure-skill
description: "Three-tier framework for what can/can't be shared about ERV portcos to third parties without an NDA; skill at ~/bin/skills/portfolio-disclosure"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: e3562743-bd7c-499d-8f3a-f224439a0a8a
---

Marcus's mental model for disclosing ERV portfolio companies (or Fund II) to third parties **without an NDA**, codified as a skill on 2026-06-18. Authoritative prompt `~/bin/prompts/portfolio-disclosure.md`; router `~/bin/skills/portfolio-disclosure/SKILL.md`; registered in CLAUDE.md; brain note `concepts/portfolio-disclosure-without-nda`.

**Three tiers.** T1 shareable (what the company does, stage, anything already public, public grants, qualitative traction like "revenue generating", named advisers on an announced mandate). T2 genericise (customer/offtaker/partner names → descriptors unless publicly announced by both sides; exact financials, valuation, cap table → qualitative/omit; named pipeline → sector-level). T3 never without Marcus's explicit per-recipient approval (Fund II anchor name = Centrica → "a FTSE-100 energy company"; anyone else's confidential info / term sheets; distress framing; pre-IPO MNPI esp. Green Li-ion; personal details).

**Why:** Disclosing competitively-sensitive numbers, named customers, others' confidential info, or distress to a non-NDA third party is a relationship and market risk Marcus controls deal-by-deal.

**How to apply:** Invoke whenever drafting any portco-facing material for an external party with no NDA (LP emails, cold outreach, intros, blurbs, decks). Composes with [[project_cold_lp_outreach_attio]] and the lp-follow-up-email skill, which inherit it and add company-specific overrides from the corrections file. Decision tests in order: public? → someone else's confidential? → reveals competitive position? → could embarrass/move a market? → would the named party be OK named to THIS recipient? → still unsure: ask Marcus. Flag every genericisation so Marcus can clear a name per recipient. Related: [[feedback_centrica_anchor_confidential]], [[feedback_no_em_dashes]].
