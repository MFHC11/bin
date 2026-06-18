---
name: portfolio-disclosure
description: >
  Marcus's decision framework for what can and cannot be shared when
  introducing ERV portfolio companies (or Fund II) to third parties
  WITHOUT an NDA. Three tiers: Tier 1 shareable (public / what-the-company-
  does / stage / public grants / qualitative traction), Tier 2 genericise
  (customer & offtaker names, exact financials, valuation, cap table,
  named pipeline → descriptors), Tier 3 never without Marcus's explicit
  per-recipient approval (the Fund II anchor's name = Centrica; anyone
  else's confidential info / term sheets; distress framing; pre-IPO MNPI;
  personal details). When unsure, ask.
triggers:
  - "introducing a portfolio company"
  - "intro <portco> to <third party>"
  - "what can I share about <portco>"
  - "can we say <fact> to <third party>"
  - "portfolio one-pager / blurb / deck for a third party"
  - "is this confidential / shareable without an NDA"
  - any task putting a portco fact in front of an external party with no NDA
mutating: false
writes_pages: false
applies_with:
  - lp-follow-up-email
  - cold LP outreach
authoritative_prompt: ~/bin/prompts/portfolio-disclosure.md
company_overrides: ~/bin/prompts/lp-follow-up-email-corrections.md
brain_note: concepts/portfolio-disclosure-without-nda
---

# Portfolio Disclosure (no NDA) Skill

## Authoritative instruction set

The full decision framework lives at:

```
~/bin/prompts/portfolio-disclosure.md
```

That file IS the skill. **Read it fresh at task start** — it is edited as
the rules evolve and this SKILL.md may drift. Company-specific figures and
named confidentiality items live in
`~/bin/prompts/lp-follow-up-email-corrections.md` and win on any specific
conflict.

## When to trigger

Invoke whenever a task will put any portfolio-company fact (or the fund's
anchor) in front of an external party and there is no NDA covering that
recipient: LP emails, cold outreach, intros, blurbs, decks, one-pagers,
DMs, or verbal-prep notes. This skill composes with `lp-follow-up-email`
and cold outreach (they inherit it and add company-specific overrides).

## The framework in one screen

**One-line rule:** default to what is already public or generic; anything
competitively revealing, anyone else's confidential information, and
anything that could embarrass a portco or move a market gets genericised
or withheld until the specific recipient is cleared. When unsure, ask Marcus.

**Tier 1 — share (no NDA needed):** what the company does; stage / round
type; anything already public (press release, website, filing, actively-
shopped deck); public non-dilutive grants (DoE, EIC, Innovate UK);
qualitative traction ("revenue generating", "commercial systems live");
named advisers on an announced mandate (Moelis, Ord Minnett on a pre-IPO).

**Tier 2 — genericise (shape, not specifics):** customer / offtaker /
partner names → descriptors ("blue-chip automotive and cathode-producer
offtakers"), UNLESS the relationship is publicly announced by both sides;
exact financials (revenue, burn, margin, valuation, cap table, ERV stake)
→ qualitative or omit; named pipeline → sector-level.

**Tier 3 — never without Marcus's explicit per-recipient approval:** the
Fund II anchor's name (Centrica / "British Gas" / "British Gas parent" →
always "a FTSE-100 energy company"); anyone else's confidential info
(term sheets, another investor's interest, counterparty numbers); distress
framing (writedowns, down-round, cash crunch, survival bridge — present
the company on its commercial traction instead); pre-IPO MNPI / selective
disclosure (extra caution for Green Li-ion); personal / relationship
details. Approval is per-recipient and does not carry forward.

**Decision tests (in order):** (1) already public? → share. (2) someone
else's confidential info? → never relay. (3) reveals competitive position?
→ genericise. (4) could embarrass / move a market? → withhold + ask.
(5) would the named third party be comfortable being named to THIS
recipient? unsure → genericise. (6) still unsure? → ask Marcus.

## Output behaviour

- Flag every genericisation / withholding to Marcus so he can clear a
  specific name per recipient.
- Pull company-specific figures + their confidentiality status from the
  corrections file first.
- Never substitute a distress-implying hedge for a withheld number;
  "revenue generating" is the neutral framing.

## Writing style

NEVER use em dashes (—) anywhere. Use a comma, colon, parentheses, or two
sentences. En dashes in numeric ranges are fine. Copy into any writing-
subagent prompt verbatim.

## Invocation

Human-initiated or auto-applied inside another writing skill. No cron, no
automation.
