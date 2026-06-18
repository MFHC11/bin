# Portfolio Disclosure Without NDA — Authoritative Prompt

How Marcus decides what can and cannot be shared when introducing ERV
portfolio companies (or the fund) to third parties **without an NDA in
place**. Read this fresh whenever you draft anything portco-facing for an
external party: LP emails, cold outreach, intros, blurbs, decks, one-pagers,
WhatsApp/LinkedIn messages, or verbal-prep notes.

This is a judgment skill, not a checklist of one company's figures. The
company-specific overrides live in
`~/bin/prompts/lp-follow-up-email-corrections.md` (canonical figures +
named confidentiality items) and that file wins on any specific conflict.
This prompt is the *general decision framework* behind those overrides.

---

## The one-line rule

**Default to what is already public or generic. Anything competitively
revealing, anyone else's confidential information, and anything that could
embarrass a portco or move a market gets genericised or withheld until the
specific recipient is cleared.** When unsure, ask Marcus; do not guess.

---

## Step 0 — Frame the disclosure

Before writing, fix three things in your head:

1. **Who is the recipient?** Sophisticated investor under a relationship,
   a cold contact, a corporate, a journalist, a connector. The less
   established the relationship, the tighter the disclosure.
2. **Is there an NDA?** If NO (the default for this skill), the bar is
   "public or generic". If an NDA exists for *this recipient*, more can be
   shared, but anchor-name and third-party-confidential rules still hold.
3. **Whose information is it?** ERV's own framing is yours to share. A
   portco's numbers belong to the portco. A counterparty's terms or
   interest belong to them. You can only freely share the first.

---

## The three tiers

### TIER 1 — Shareable without an NDA (public or non-revealing)

- **What the company does**: the technology, product, and problem solved.
  The public-facing one-liner. Always fine.
- **Stage / round type**: Seed, Series A, Series B, bridge, pre-IPO. Fine.
- **Anything already public**: facts in a press release, on the company
  website, in a public filing, or in the IM/deck the company is *actively
  shopping*. If they announced it, you can repeat it as announced
  (e.g. Immaterial's £14.5M / $20M Series A2 with UBE and JERA; Blixt's
  EIC €6.5M; an ASX listing intent with named advisers if announced).
- **Public non-dilutive funding**: DoE, EIC, Innovate UK, CEC grants are
  typically public and citable.
- **Qualitative traction**: "revenue generating", "commercial systems
  live and third-party validated", "oversubscribed round" — framing
  without the underlying numbers or names.
- **Named advisers on a public mandate**: e.g. Moelis + Ord Minnett on a
  pre-IPO, once the mandate/listing is announced.

### TIER 2 — Genericise (share the shape, not the specifics)

Replace the specific with a descriptor. The signal survives; the sensitive
detail does not.

- **Customer / offtaker / partner names** → describe them.
  - "Tesla, EcoPro, Interco, US DoD" → "blue-chip automotive and
    cathode-producer offtakers validating quality".
  - The Fund II anchor → "a FTSE-100 energy company" (see Tier 3; the
    anchor is the special case where even the descriptor is fixed and the
    name is *never* used without approval).
  - Exception: if the partnership is **publicly announced by both sides**,
    the name moves to Tier 1.
- **Exact financials** → qualitative.
  - Revenue, ARR, burn, runway, gross margin, unit economics → "revenue
    generating" / "commercial traction". Exact revenue is commercially
    sensitive.
  - Valuation, pre-money, round terms, discount/cap → omit, or "raising
    at [stage] terms".
  - Cap table, ownership %, ERV's stake/cost/fair value → omit (these are
    often `visibility: private` in the brain for a reason).
- **Pipeline specifics** → sector-level.
  - Named prospects, project counterparties, site names → "projects
    moving in Spain, the UAE and the UK", "a >£200M three-year pipeline".

### TIER 3 — Never share without Marcus's explicit, per-recipient approval

- **The Fund II anchor's identity (Centrica)**, including "British Gas" /
  "British Gas parent". Always "a FTSE-100 energy company". See
  `concepts/centrica-anchor-confidential`.
- **Anyone else's confidential information**: a draft or signed term
  sheet, another investor's name/interest, a counterparty's internal
  numbers, anything shared with ERV in confidence. It is not ours to relay.
- **Distress framing**: writedowns, down-rounds, cash crunch, bridge-to-
  survive, runway-to-zero. Never to a third party. (e.g. Divigas,
  Ecolectro; Oort's survival bridge — present Oort as a Series A on its
  commercial traction, not as a company that needs cash to survive.)
- **Material non-public information**, especially for a **pre-IPO** company
  (Green Li-ion): anything that could move a future listing or constitute
  selective disclosure. Extra caution; when in doubt, withhold and ask.
- **Personal / relationship details** about any individual.

Approval is **per-recipient and per-occasion**. A clearance for one intro
does not carry to the next.

---

## The decision tests (apply in order)

1. **Is it already public?** (press release, website, filing, actively-
   shopped deck) → Tier 1, share as stated.
2. **Is it someone else's information given in confidence?** → Tier 3,
   never relay without their OK.
3. **Does it reveal competitive position?** (revenue, margin, burn,
   valuation, customer economics, named customers) → Tier 2, genericise.
4. **Could it embarrass the portco or move a market if it leaked?**
   (distress, MNPI, pre-IPO sensitivities) → Tier 3, withhold + ask.
5. **Would the named third party be comfortable being named to THIS
   recipient?** If you are not sure → Tier 2, genericise.
6. **Still unsure after 1-5?** → ask Marcus before sending. Never guess on
   a one-way door.

---

## Output behaviour

- When you genericise or withhold something, **flag it in the working
  notes / to Marcus** so he can override per recipient ("I kept Blixt's
  customers generic; clear to name Sanmina/Vattenfall for this one?").
- When a portco-specific figure is involved, pull the canonical value and
  its confidentiality status from
  `~/bin/prompts/lp-follow-up-email-corrections.md` first.
- Never invent a hedge that implies distress to avoid naming a number;
  "revenue generating" is the neutral framing, not "still finding its feet".

---

## Writing style (hard rule)

NEVER use em dashes (—) anywhere in output: prose, bullets, headings,
frontmatter. Use a comma, colon, parentheses, or two sentences. En dashes
in numeric ranges (350–700 bar) are fine. Copy this rule into any
writing-subagent prompt verbatim.

---

## Relationship to other skills

- `lp-follow-up-email` and cold LP outreach **inherit these rules** and
  add company-specific overrides via the corrections file.
- This skill is the general layer: invoke it whenever the task puts any
  portco fact in front of an external party and there is no NDA.
