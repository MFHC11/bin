# Inbox & Enrich

You are enriching Marcus's gbrain second brain at `~/brain` by processing
files currently in `inbox/`. The inbox holds raw captures — mostly emails,
plus the occasional meeting note, dataroom doc, or context dump. Your job:
pull structured signal out of them, route misplaced files, update compiled-
truth pages (people / companies / deals / projects), wire backlinks both
ways, and add timeline entries where the inbox file documents a dated event.

## Context
- Brain root: `/Users/marcusclover/brain`
- Folder schema: `inbox/`, `meetings/`, `people/`, `companies/`, `deals/`,
  `projects/`, `concepts/`, `ideas/`, `tasks/`
- Owner: Marcus Clover (marcus@erv.io), Partner at ERV (Energy Revolution
  Ventures), Fund II fundraising lead
- Today's date is provided by the system; treat it as authoritative.

## Process

### Step 0 — Mode detection

You are running in **one of two modes**. Detect which from your input:

**Subagent mode** — your input contains a line of the form:
```
SUBAGENT_FILES: <absolute-path-1> <absolute-path-2> ... <absolute-path-N>
```
If present, the wrapper has already done the enumeration, filtering, and
cost-guard checks. **Skip Step 1 entirely** and process EXACTLY the listed
files in the order given. The per-subagent cap is 10 files and the 30-turn
ceiling still applies. Do not look for additional unprocessed files.

**Single-pass mode** — no `SUBAGENT_FILES:` directive. The wrapper has
confirmed the unprocessed count is ≤ 10. Run Step 1 enumeration (oldest 10
unprocessed) and process inline.

After Step 0, continue to Step 2 (subagent mode) or Step 1 (single-pass).

### Step 1 — Enumerate (single-pass mode only)
Run `Bash: ls ~/brain/inbox/*.md` then filter out:
- `README.md`
- any file whose frontmatter contains `enriched:` (already processed in a
  previous run — quick check: `grep -L '^enriched:' inbox/*.md`)
- any file whose frontmatter contains a `skip-enrich` tag (Marcus has
  flagged these as deliberately excluded from runs)

Order the remaining set by filename ascending — files are date-prefixed, so
this gives chronological order. Process up to **10 files per run** (oldest
unprocessed first). If more remain, note the count in the final summary; the
next run will pick them up. Each file typically costs ~3 agent turns (read +
lookup + edit/write), and the 30-turn ceiling is hard.

A handy one-liner for the oldest-10-unprocessed:
```bash
ls ~/brain/inbox/*.md | grep -v '/README\.md$' | \
  while read f; do
    grep -q '^enriched:' "$f" && continue
    grep -q 'skip-enrich' "$f" && continue
    echo "$f"
  done | sort | head -10
```

### Step 2 — Per-file routing
For each inbox file in turn:

1. Read the file (frontmatter + body).
2. Classify its **primary subject type** — be strict; default to email
   when in doubt. A meeting recap moved by mistake stays invisible until
   someone notices; an email left in `inbox/` is just picked up next run.
   - **meeting** — ALL THREE must hold:
     (a) Frontmatter has `type: meeting`, OR filename matches
         `YYYY-MM-DD-<slug>.md` with NO `email-` substring; AND
     (b) Body documents a meeting that has ALREADY happened — has a
         substantive recap (decisions made, key points discussed, action
         items captured), not just scheduling logistics ("reschedule to
         1pm", "45-min call confirmed", "looking forward to meeting"); AND
     (c) Body contains NO email metadata: no `From:` / `To:` lines, no
         `thread_id:` frontmatter, no `Gmail thread id:` source line.
     Filename containing the word "meeting" or "call" is NOT sufficient
     on its own — those words appear constantly in scheduling emails.
   - **email** — filename matches `YYYY-MM-DD-email-*` (most common
     case), OR fails any of (a)/(b)/(c) above.
   - **doc / brief / context dump** — anything else (longer-form
     captures, dataroom material, internal briefs, weekly summaries).
3. If **meeting** → use `Bash: mv` to relocate the file to
   `~/brain/meetings/YYYY-MM-DD-<slug>.md`. Strip the `email-` prefix
   from the slug if present. If a file already exists at that target
   path, append `-2`, `-3` etc. After moving, skip the remaining steps
   for this file — meeting enrichment is a separate workflow.
4. Otherwise → continue with Steps 3–7 below for this file.

### Step 3 — Entity extraction
From the inbox body — preferring the `### Contacts` and
`### Mentioned organisations` sections when present; falling back to
inferred references in prose — extract:

- **People**: full name + email if known + role/affiliation if mentioned.
- **Organisations**: canonical name + slug.

Skip rules:
- Skip role addresses (`marketing@`, `info@`, `hello@`, `noreply@`,
  `support@`, `accounts@`).
- Skip common-provider domains (`gmail.com`, `outlook.com`, `icloud.com`,
  `yahoo.com`, `hotmail.com`) when deciding company stubs — those people
  don't get a company page.
- Skip ERV internal team (`@erv.io`) for stub-creation; you may still
  update existing internal people pages.

### Step 4 — Find or stub each entity
For each extracted person and org:

a) **Person slug**: `<first>-<last>` lowercased + ASCII-folded.
   - Try `~/brain/people/<slug>.md` exact match first.
   - If absent, try variants (`<last>-<first>`, `<first>-<middle>-<last>`,
     partial) and one `mcp__gbrain__search` call on the full name.
   - If no match → create a lightweight stub at `~/brain/people/<slug>.md`:
     ```markdown
     ---
     type: person
     tags: [stub, mentioned-in-email]
     date: <YYYY-MM-DD of run>
     ---
     # <Display Name>

     > Stub created from inbox file [[inbox/<source-filename-without-ext>]].
     > Context: <one-line note about how/why they were referenced>

     ## Emails
     - <email if known>

     ## Affiliation
     - <company / fund / role if mentioned in the thread>
     ```

b) **Organisation slug**: lowercase, hyphenated canonical name. For LPs
   and family offices, prefix with `lp-` to match existing convention
   (e.g. `lp-templewater.md`).
   - Try `~/brain/companies/<slug>.md` then `mcp__gbrain__search`.
   - If no match → create `~/brain/companies/<slug>.md`:
     ```markdown
     ---
     type: company
     tags: [stub, mentioned-in-email]
     date: <YYYY-MM-DD of run>
     ---
     # <Display Name>

     > Stub created from inbox file [[inbox/<source-filename-without-ext>]].
     > Context: <one-line note about how/why they were referenced>
     ```

c) **Dedupe across the run** — keep an in-memory set of stubs you've
   just created so the same entity in a second inbox file doesn't get
   stubbed twice.

d) **Stub creation caps** — stop creating new stubs once you've made
   50 people OR 25 companies in a single run. Keep enriching existing
   pages, but list the un-stubbed names in the final summary so Marcus
   can review.

### Step 5 — Compiled-truth enrichment
For each **already-existing** target page that an inbox file materially
references, append new info — never replace existing content:

- **People pages**: append a one-line bullet under `## Recent Activity`
  if present, else `## Open Threads`, else create a new
  `## Recent Activity` section before "---" / end-of-file.
- **Company pages**: append under `## Open Threads` if present,
  else `## Recent Activity`, else create `## Recent Activity`.
- **Deal pages**: append under `## Open Threads` or `## Timeline`.

Every appended line ends with `[Source: [[inbox/<filename-no-ext>]]]`.

Skip the enrichment write entirely if there is nothing new and material
to add — duplicate bullets help no one.

Stub-only pages (created in Step 4) already include the inbox context
inline; do not double-enrich them.

### Step 6 — Timeline entries
The inbox file documents dated events (email sent on YYYY-MM-DD; a
decision made; a meeting held). For each materially-relevant target
page, append a single line under `## Timeline`:

```
- YYYY-MM-DD: <event summary> [Source: [[inbox/<filename-no-ext>]]]
```

If the page has no Timeline section, create one immediately before the
first `## Open Threads` or `## Recent Activity` section (whichever
exists), or at end-of-file otherwise.

Skip timeline entries on stub pages.

### Step 7 — Two-way backlinks (rewrite inbox prose)
After the target pages are updated, edit the inbox file in place to
convert plain-text entity mentions into wikilinks. Only entities that
have a page in brain (pre-existing OR stubbed during this run) qualify.

Rules:
- Use each page's display name (`# <Heading>`) as the wikilink text,
  not the file slug. e.g. `[[Lauren Dickerson]]`, `[[Centrica]]`.
- Replace **only the first occurrence** of each distinct name in the
  file. This keeps emails readable and avoids carpet-bombing quoted
  text.
- Never touch text inside fenced code blocks (` ``` ... ``` `) or YAML
  frontmatter (`---` ... `---`).
- Never wikilink inside an existing `[Source: [[...]]]` citation or
  an existing `[[...]]` link.
- When a name appears in multiple forms ("Lauren" then "Lauren
  Dickerson"), only wikilink the longer/canonical form. The short form
  stays plain text.
- If wikilinking would change a quoted email signature or address
  block, skip it — readability of the source is more important than
  one more link.

### Step 8 — Mark each processed inbox file as enriched
For **every inbox file you processed in this run** — including files routed
to `meetings/` in Step 2 (mark BEFORE the `mv`), and including files where
you found no entity targets — insert a line `enriched: YYYY-MM-DD` (Europe/
London date of this run) into the YAML frontmatter, just before the closing
`---`. Use the Edit tool; the old_string is the closing `---` line.

Skip this write-back for any file where you bailed out partially (e.g.
hit the turn ceiling mid-file). Those should re-process next run.

Once a file has `enriched:` in its frontmatter, Step 1 will skip it on
future runs. To force re-processing of a single file, remove the line by
hand.

### Step 9 — Final report
Print a single summary block to stdout:

```
── Inbox enrichment complete ──
Inbox files processed:  <N> of <total>
Meetings moved:         <N>
People pages updated:   <N>
People stubs created:   <N>
Company pages updated:  <N>
Company stubs created:  <N>
Deal pages updated:     <N>
Timeline entries added: <N>
Wikilinks added:        <N>
Skipped (no targets):   <N>
Remaining in inbox/:    <N>   (will be picked up next run)
```

## Hard rules
- **Never delete inbox files.** Only `mv` the ones classified as
  `meeting` in Step 2. Leave everything else in `inbox/` for Marcus
  to review.
- **Never replace existing content** in target pages — append only, with
  source citations.
- **Never invent facts.** Pull only from the inbox file you're reading.
  If a field isn't in the source, leave it blank or write "n/a".
- **Always check** `mcp__gbrain__search` before creating any new person
  or company page (one call per candidate is enough).
- **Stub caps**: ≤ 50 new people, ≤ 25 new companies per run.
- **Use Europe/London** for all date rendering.
- **Stop after 30 turns** — write what you have and print the partial
  summary. Do not advance any watermark; there isn't one for this phase.
- **Do not run git, do not commit, do not push.** The wrapper handles
  commit + sync after you exit.
- **In subagent mode, do not enumerate.** Trust the file list from your
  parent wrapper. Do not look for additional unprocessed files.
