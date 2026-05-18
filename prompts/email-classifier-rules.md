# Email Classifier — Learned Rules

## Last updated: 2026-05-10
## Sessions: 2

This file is read by `~/bin/lib/brain-email-context.sh` (or the cal-mail-weekly-sync prompt) on every future run and injected alongside the live brain context for the Haiku classification pass.

When two rules conflict, more specific rules take precedence in this order: **Domain > Name > Pattern > Context**. Within a category, the most-recently-added rule wins.

---

## Domain Rules

### LP / family-office / shareholder relationships → HIGH/lp-comms
- `@actions.capital` → HIGH/lp-comms (David Velasquez — HNWI LP)
- `@asteriacapital.com` → HIGH/lp-comms (Zuzana — potential LP)
- `@paloneo.org` → HIGH/lp-comms (family-office community / coworking)
- `@shivelightcapital.com` → HIGH/lp-comms (Jeremy/Jip — LP)
- `@energia.ee`, `@enefit.com` → HIGH/lp-comms (Emil Metsson — Estonian utility, strategic LP)
- `@rainmakergroup.com` → HIGH/lp-comms (Rainmaker Group — potential LP)
- `roxana.mirica@apax.com` → **URGENT**/lp-comms (Roxana — top co-investor at Apax, key HoldCo LP)
- `david.roca.salvado@gmail.com` → HIGH/lp-comms (David Roca — existing ERV HoldCo shareholder, also Brolio)
- `federico.travella@gmail.com` → HIGH/lp-comms (Federico — large family office contact)

### Capital raisers / placement / fund admin → HIGH
- `@akvrgroup.com` → HIGH/admin (George Vives-Rouco — capital raiser for LPs, RCAL onboarding)
- `@firstavenue.com` → HIGH/admin (placement agent + NAV loan provider — Maulik, Badran, Charlie)
- `victoria.moiani@iqeq.com` → HIGH/admin (IQ-EQ entity admin around LP-tier vehicles like Nauval)

### Bots / automated → IGNORE
- `@erventures113.onmicrosoft.com` → IGNORE (MS Teams/SharePoint group-add notifications)
- `@apollomailtester.com` → IGNORE (automated mail-health test recipient)

## Name Rules

(none — all current name-level overrides expressed as domain rules above)

## Pattern Rules

### → HIGH
- Subject matches `Connection .+ <> .+` → HIGH/portfolio (helping a portfolio company connect to an investor)
- Subject contains `NAV loan` (case-insensitive) → HIGH (NAV-loan threads are key fund-finance activity)
- Subject contains `KYC`, `RCAL`, or `Onboarding` → HIGH/admin (fund admin intake — typically tied to a key contract or LP entity)
- Subject contains `plexus` OR `Adaptive gatherings for adaptive infra` → HIGH (Plexus event series for ecosystem LPs)
- Subject contains `Invoice payment` from `marcus@erv.io` to ERV team → HIGH/admin (time-critical fund-bill correspondence; e.g., Systemiq)
- Sender = `no-reply@fathom.video` AND subject starts with `Recap of your meeting with` → HIGH (auto-generated but substantive — contains meeting takeaways and action items)

### → LOW
- Subject contains `Equity Fundraising`, `Subscription Agreement`, or `ERV Subscription` from `hayden@erv.io` / `tom.lepage@invictawealthsolutions.com` AND no explicit deadline keyword (`signing deadline`, `wire deadline`, `due by`) → HIGH (downgrade from URGENT — fund admin without time pressure)
- Subject starts with `Updated invitation:` → LOW (calendar reschedule logistics, not substantive content)
- Subject starts with `Met at ` (event context) without LP/portfolio relevance → LOW (social/press networking)
- Subject contains `FTSE100 energy company anchors ERV Fund II` → LOW (outbound broadcast template — applies regardless of latest sender; will be auto-promoted to HIGH on the inbound side via LP domain rules when an LP replies). **Tightened from session 1.**

### → IGNORE
- Subject contains `added you to the ` OR `is inviting you to collaborate on` → IGNORE (group/dataroom admin notifications)
- Subject = `Routine Health Check` → IGNORE (Apollo deliverability test)
- Subject starts with `Fwd: Adequita Capital` from `marcus@erv.io` → IGNORE/noise (brother's deal, not ERV)

## Context Rules

- Cold inbound startup pitch from unknown sender, NO warm-intro language (`X suggested I reach out`, `via X`, `forwarded by X`, `intro from X`) → MEDIUM (refines the default "any new external contact = HIGH" — restricts HIGH to genuinely warm intros).
- Subject mentions a known LP/VC by name (e.g. `Molten`, `Carbon Equity`, `Pandan`, `Aldea`) AND the sender is a contact who could broker the intro → HIGH/lp-comms (potential LP intro pathway).
- **LP/VC sender lookup**: at runtime, scan `companies/lp-*.md` and any company page tagged `[lp,...]` to extract sender domains/emails; treat any sender matching that list as **HIGH/lp-comms minimum**, even if no explicit domain rule above. The list of explicit domain rules (`## Domain Rules › LP / family-office`) above is the manually-curated subset; the dynamic lookup catches the long tail.
- **Calendar bot-RSVP override** (added Session 2): if subject **starts with** any of `Accepted:`, `Declined:`, `Tentatively Accepted:`, `Aceptado:`, `Aktsepteeritud:`, `Canceled event`, `Updated invitation:`, `Updated invitation with note:` (no `Re:` prefix), classify as LOW/noise **regardless of sender domain**. LP domain promotions do NOT override these — they are bot acceptance/decline notifications and reschedule logistics, not substantive correspondence. Note: human-sent `Invitation:` subjects (e.g., a portfolio founder inviting the team to a meeting) are NOT covered here — they retain their substantive classification. Threads with `Re:` prefix indicate a human reply and remain subject to normal domain rules.

---

## How to extend

Add new rules under the appropriate section. Format: `<trigger>` → `<priority>` (`<one-line reason>`).

Session log:
- Session 1 (2026-05-09): 6 rules from initial 13-thread test corrections.
- Session 2 (2026-05-10): +18 rules from 7-day backfill (26 user corrections); tightened Rule 3 (Fund II broadcast) to subject-only match.
