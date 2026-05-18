# Weekly Calendar + Email → Brain Sync

You are syncing the last 7 days of Google Calendar events and Gmail threads
into Marcus's gbrain second brain at `~/brain`. Be precise, deduplicate
aggressively, and write only what is genuinely new or materially changed.

## Context
- Brain root: `/Users/marcusclover/brain`
- Schema folders: `inbox/`, `meetings/`, `people/`, `companies/`, `deals/`,
  `projects/`, `concepts/`
- Owner: Marcus Clover (marcus@erv.io), Partner at ERV (Energy Revolution
  Ventures), Fund II fundraising lead
- Team calendars accessible: harry, peter, hayden, philippos, carolyn, grant
- Today's date is provided by the system; treat it as authoritative

## Auto-load on every run
Before classifying any email, run these two helpers and inject their output
into the Haiku classification prompt:

1. **Live brain context** — execute `~/bin/lib/brain-email-context.sh` and
   capture stdout. It surfaces hot LPs, active portfolio names, and open
   action items pulled fresh from gbrain + tasks/active.md.

2. **Learned classifier rules** — read `~/bin/prompts/email-classifier-rules.md`.
   Apply each rule (Domain → Name → Pattern → Context, in that precedence
   order) deterministically as a pre-pass before/alongside Haiku. New rules
   are appended here over time via the user-correction reinforcement loop;
   they should always take precedence over Haiku's default classification.

## Watermark — read FIRST
1. Read `~/brain/.last-email-sync` via the Read tool.
2. If the file exists and contains an ISO-8601 timestamp, use that as the
   lower bound for both Calendar and Gmail queries.
3. If the file is missing, empty, or unparseable, default to **7 days ago
   from now**.
4. Capture today's "now" as a single ISO-8601 string at the start of the run
   and write it to `~/brain/.last-email-sync` ONLY at the very end, after
   all writes succeed. Do not update the watermark on partial failure.

## Step 1 — Calendar sync

Use `mcp__claude_ai_Google_Calendar__list_events` for marcus@erv.io and the
team calendars (harry, peter, hayden, philippos, carolyn, grant).

Filter rules:
- Time range: watermark → now
- Keep events with **2+ attendees** (excluding marcus alone, declined-only,
  and pure focus blocks)
- Drop all-day OOO/holiday entries, internal 1:1 admin (e.g., "Lunch",
  "Dentist"), and recurring stand-ups unless they have a clear external
  participant
- Drop events the team owner declined

For each kept event:

1. Build a slug: lowercase ASCII title, replace non-word chars with `-`,
   collapse repeats, trim to ~6 words.
2. Compose target path: `~/brain/meetings/YYYY-MM-DD-[slug].md` using the
   event start date in Europe/London.
3. **Dedupe check** — before writing:
   - If the file already exists at that path, skip.
   - Otherwise call `mcp__gbrain__search` (or equivalent gbrain search tool)
     for the title + key attendees. If a meeting note already covers this
     event, skip.
4. Write the file in this exact format:

   ```markdown
   ---
   type: meeting
   tags: [meeting]
   ---
   # <Event Title>

   <Day, DD Mon YY> · <comma-separated attendee display names>

   ### Summary
   - <2–4 bullets describing purpose, drawn from the event description
     and any linked agenda. If no description, write: "No agenda provided."

   ### Attendees
   - [[<person-stub-or-link>]] — <org if known>
   - ...

   ### Source
   - Google Calendar event id: <event id>
   - Organizer: <organizer email>
   ```

   Add additional tags from this set when applicable (space-separated on
   the `tags:` frontmatter line as a YAML list):
   `#meeting` (always), `#lp` (LP/investor prospect), `#portfolio`
   (existing portfolio company), `#deal` (live deal/pipeline),
   `#intro` (first-time intro meeting). Use brain context to classify;
   when unsure, only tag `#meeting`.

5. **Stub creation** — for each attendee whose email domain is *external*
   to erv.io:
   - Person slug: `<first>-<last>` lowercased and ASCII-folded.
   - If `~/brain/people/<slug>.md` does not exist AND gbrain search returns
     no hit, create it:
     ```markdown
     ---
     type: person
     tags: [auto-stub]
     ---
     # <Display Name>

     - Email: <email>
     - First seen: <YYYY-MM-DD via meeting [[meetings/YYYY-MM-DD-slug]]>
     ```
   - For the attendee's company (derived from email domain, skipping common
     providers like gmail/outlook/icloud), do the same against
     `~/brain/companies/<company-slug>.md`.

## Step 2 — Gmail sync

Use `mcp__claude_ai_Gmail__search_threads` against marcus@erv.io.

Run these queries (all bounded by `after:<watermark>`):
- `from:OR to: keywords for investor/LP language` →
  `(LP OR "limited partner" OR investor OR commitment OR allocation OR
  "side letter" OR subscription) newer_than:7d`
- `(portfolio OR "board update" OR KPI OR runway OR bridge OR followon)
  newer_than:7d`
- `("term sheet" OR LOI OR SAFE OR "convertible note" OR diligence OR
  "data room" OR DDQ) newer_than:7d`
- `(intro OR introduction OR "happy to connect" OR "warm intro")
  newer_than:7d`
- `(legal OR counsel OR attorney OR Cooley OR Goodwin OR Mishcon OR
  Travers) newer_than:7d`

For each unique thread returned (dedupe by thread id across queries):

1. Fetch the thread with `mcp__claude_ai_Gmail__get_thread`. Read the most
   recent 3 messages plus the original.
2. Skip noise: newsletters, calendar invites already captured in Step 1,
   pure scheduling pings with no substance, automated alerts, recruiter
   spam, marketing.
3. **Dedupe check** — call gbrain search for the thread subject and the
   counterpart's name. If brain already has a recent (<14 days) note with
   the same subject or substantive overlap, skip.
4. Write to `~/brain/inbox/YYYY-MM-DD-email-<short-slug>.md`:

   ```markdown
   ---
   type: inbox
   tags: [<see classification below>]
   thread_id: <gmail thread id>
   ---
   # <Thread subject>

   <YYYY-MM-DD> · <counterpart name> (<counterpart email>)

   ### Summary
   - <3–6 bullets capturing what was actually discussed, decisions, asks,
     and dates. Quote sparingly; paraphrase otherwise.>

   ### Action / Next Step
   - <Marcus's pending action, or "Awaiting reply from <name>">

   ### Contacts
   - <Every named individual referenced in the thread — sender, recipients,
     people CC'd, and anyone mentioned by name in the body. One bullet each,
     format: `- Full Name (email if known) — affiliation/role if mentioned`.
     Include team members (e.g. peter@erv.io) so cross-references are
     captured.>

   ### Mentioned organisations
   - <Every company, fund, family office, or institution named — even if
     in passing. One bullet each.>

   ### Source
   - Gmail thread id: <thread id>
   - Last message: <ISO timestamp>
   ```

   Classification tags (apply 1–3, all on the `tags:` frontmatter list):
   - `#lp` — LP prospects, allocators, family offices, fund-of-funds
   - `#portfolio` — existing portfolio company comms
   - `#deal` — new pipeline / live deal
   - `#intro` — warm intros (inbound or outbound)
   - `#legal` — counsel, term-sheet markup, side letters
   - `#meeting` — only if the email is itself a meeting recap

5. **Stubs — broad scan** (replaces narrower Step 1 logic for inbox files).

   After writing the inbox file, scan its `### Contacts` and
   `### Mentioned organisations` sections. For **every named person and
   organisation** listed there (not just the counterpart, not just LP-tagged
   ones), do the following:

   a. **Person**:
      - Derive slug: `<first>-<last>` lowercased and ASCII-folded.
      - Try matching in `~/brain/people/`: exact slug, then variants
        (`<last>-<first>`, partial), then run gbrain search on the full name.
      - If no match in either, create `~/brain/people/<slug>.md`:
        ```markdown
        ---
        type: person
        tags: [stub, mentioned-in-email]
        date: <YYYY-MM-DD of run>
        ---
        # <Display Name>

        > Stub created from inbox file [[inbox/YYYY-MM-DD-email-<short-slug>]].
        > Context: <one-line note about how/why they were referenced>

        ## Emails
        - <email if known, else leave section header but no bullet>

        ## Affiliation
        - <company/fund/role if mentioned in the thread>
        ```

   b. **Organisation**:
      - Derive slug from the canonical name (lowercase, hyphenated). For
        family offices and LPs, prefix with `lp-` to match existing
        convention.
      - Match against `~/brain/companies/` + gbrain search.
      - If no match, create `~/brain/companies/<slug>.md` with `type: company`,
        `tags: [stub, mentioned-in-email]`, and a one-line context note.

   c. **Skip if already stubbed in this run** — don't create duplicates
      across multiple inbox files in the same sync. Track newly-created
      stubs in memory and dedupe by slug.

   d. **Skip role addresses** — `marketing@`, `info@`, `hello@`, `noreply@`,
      `support@`, `accounts@` etc. are not people; only stub them as
      `companies/<domain-slug>.md` if the org isn't already stubbed.

   This rule applies to ANY named person/org in the Contacts section,
   regardless of LP-tag or apparent priority. The goal: future runs
   should never trip over an unknown name. Stubs are cheap, deduplication
   later (via gbrain enrichment / dream cycle) is cheap; gaps in the brain
   are expensive.

## Step 3 — Watermark + report

1. Update `~/brain/.last-email-sync` with the run-start ISO timestamp.
2. Print a final summary to stdout:
   ```
   ── Weekly sync complete ──
   Calendar: <N> meetings written, <N> skipped (dedup)
   Gmail:    <N> inbox notes written, <N> skipped (dedup/noise)
   Stubs:    <N> people, <N> companies created
   Watermark advanced to: <ISO timestamp>
   ```

## Hard rules
- **Never overwrite** an existing file. If a path collides, append a
  `-2`, `-3` suffix to the slug.
- **Never invent attendees, dates, or content.** If a field isn't in the
  source, leave it blank or write "n/a".
- **Always check gbrain search** before creating any new file (meeting,
  inbox, person, company stub). One search per candidate is enough.
- **Use Europe/London** for all date rendering.
- **Stop after 30 turns** — if you can't finish, write what you have and
  do NOT advance the watermark.
- **Do not run git, do not run brain-sync.** The wrapper script handles
  commit + sync after you exit.
