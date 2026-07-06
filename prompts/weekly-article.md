# Weekly Article Loop (authoritative instructions, read fresh each run)

You are running Marcus Clover's weekly article-drafting loop on the brain at
/Users/marcusclover/brain. Your job: pick the best next idea from the backlog,
retrieve evidence, draft in the house voice, run the critic, deliver a file, and
update pipeline state. Public writing routes to a frontier model (governor rule).

MODE DETECTION: if your input contains a line `MODE: headless`, you are running
unattended. Every "wait for Marcus" step below then degrades as specified. Otherwise
you are interactive: pause where the steps say so.

TOOLING NOTE: prefer the brain MCP tools (query, think, list_pages, get_page,
resolve_slugs, put_page, add_tag, takes_list, get_recent_salience; exposed as
mcp__claude_ai_brain__* in Claude Code). In headless/cron contexts the MCP server can
be absent; fall back to the gbrain CLI (`gbrain get <slug>`, `gbrain put <slug>`,
`gbrain search`, env from ~/.gbrain/secrets.env) plus filesystem reads. The backlog
page is DB-ONLY (no file in the repo); it must be read and written via MCP or gbrain
CLI, never via the filesystem.

NEVER use em dashes in anything you write: not in drafts, notes, status lines, or
page edits. Use a comma, colon, parentheses, or two sentences. En dashes inside
numeric ranges (350-700 bar) are fine. Copy this rule verbatim into the prompt of
any subagent that writes.

## Step a. LOCATE the backlog

Canonical source (confirmed by Marcus 2026-07-03): the DB page
`concepts/erv-content-ideas` (blog and LinkedIn idea queue, ~20 ideas in lettered
themes A-E plus a "Publish first" trio; statuses move idea -> drafting -> published;
each idea carries seed slugs). Fetch it with get_page.

- Interactive: show a one-paragraph summary (idea count by status, themes present)
  and ask Marcus to confirm it is still the right source before continuing.
- Headless: verify the page exists and contains at least one unstarted idea; if yes
  proceed, if no, stop and write a short report saying the queue is empty or moved.
- If the page has moved: use resolve_slugs / list_pages / query to find its
  successor, and say what you found.

## Step b. SCORE and pick

Score EVERY unstarted idea (status still "idea", no drafting/published marker, no
retired marker) on this rubric. Each axis 0-5, multiplied by its weight; max 70:

- Thesis compounding x3: does it build the Universal Work Machine / electrification
  worldview and make the next piece stronger?
- Evidence readiness x3: are the numbers and seed pages already in the brain? (Read
  the seed slugs listed on the idea; an idea whose seed page is missing scores low.)
- Differentiation x2.5: could only Marcus/ERV credibly write this?
- Timeliness x2: does it ride a live wave (AI datacentres, price crossovers, news)?
- Audience pull x2: will LPs, founders and operators actually engage?
- Low-effort/low-risk x1.5: short format, no confidentiality landmines, no heavy
  verification burden.

Then apply sequencing overrides on top of raw score:

1. Front-load high evidence-readiness: an idea scoring 5 on readiness beats a
   higher-total idea scoring 2 or less on readiness.
2. Tentpole rhythm: roughly one tentpole ([BLOG] or [SERIES] opener) per two lighter
   [LI] pieces. Check the run log (step f) for what shipped recently.
3. Variety guard: never the same theme letter (A-E, or "P" for the publish-first
   trio) two weeks running. Check the run log.
4. Retire stale ideas: if an idea has been overtaken by events or duplicates a
   published piece, mark it retired on the backlog page (status note) and say so.
5. Evergreen fallback: always name one evergreen idea (typically Theme A) that could
   ship any week if the pick falls through.

Present a ranked TOP 5 with per-axis scores, the weighted total, and a one-line
rationale each, plus your recommended pick and the evergreen fallback.

- Interactive: WAIT for Marcus to confirm or override the pick. Do not proceed.
- Headless: auto-pick the top-ranked idea after overrides, and open the delivered
  draft's working notes with a short "why this one picked itself" paragraph.

## Step c. RETRIEVE evidence

For the chosen idea: read its seed slugs (get_page), then widen with think/query on
the idea's core claims, and get_recent_salience / takes_list if the piece benefits
from a live angle. Build an evidence sheet: each claim or number with its source
slug. Numbers you cannot ground in a page get a [verify: ...] placeholder in the
draft, never an invention. Canonical-figure discipline: if a portfolio or fund
figure appears, ~/bin/prompts/lp-follow-up-email-corrections.md wins over the brain
on conflict.

## Step d. DRAFT, then CRITIC

Read ~/bin/skills/article-persona/SKILL.md fresh and follow it exactly: voice hard
rules, AI-tell screen, calibration targets, structure template for the idea's format
([LI] 250-400 words, [BLOG] 800-1,200, [SERIES] as blog with continuity lines),
deliberate placeholders, confidentiality gate (anchor never named; portfolio facts
through the portfolio-disclosure tiers).

Then run the skill's mandatory critic pass as a separate read: rewrite in place,
keep a critic log. The draft is not deliverable until the critic pass is clean.

## Step e. DELIVER

Write the post-critic draft to:
  /Users/marcusclover/brain/drafts/articles/YYYY-MM-DD-<idea-id>-<slug>.md
(e.g. 2026-07-10-b8-ai-bottleneck-5-30-mw.md). File contains: the draft, then a
`## Working notes` section with: idea id and theme letter, format, weighted score
and rationale, the evidence sheet (claim -> source slug), the critic log, open
placeholders Marcus must fill, and any confidentiality flags.

Interactive: also present the draft inline. Headless: the file is the deliverable;
if a notification channel is available, send a one-line pointer.

## Step f. MARK state (so next week's run is correct)

On the backlog page `concepts/erv-content-ideas` (via put_page; preserve ALL other
content byte-for-byte, append/edit only what is specified):

1. Update the chosen idea's line: append `(status: drafting since YYYY-MM-DD)`.
2. Append to (or create) a `## Run log` section at the end of the page:
   `- YYYY-MM-DD: <idea-id> <title> [format] theme <letter>, draft at
   drafts/articles/<filename>`. This is the variety guard's memory.
3. add_tag the page with `drafting-<idea-id>` (e.g. drafting-b8).

Then append one JSONL line to
~/brain/.tasks/skill-evolution/weekly-article/ledger.jsonl:
{"ts":"<iso>","version":1,"outcome":"success|partial|fail","notes":"<idea id, format,
what the critic caught, headless or interactive>","cost_usd":0}

Do not run git; the daily backup commits drafts/. Do not touch other backlog ideas
except an explicit retirement from step b.
