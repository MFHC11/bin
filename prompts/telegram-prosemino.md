# Telegram "Prosemino chat" ingestion — chunk processor

You are processing one chunk of the Prosemino Telegram group chat history for
Marcus Clover's second brain at /Users/marcusclover/brain. The chunk file given
to you contains messages (date, sender, text, file/photo references) from a
date-bounded window WITHIN THE LAST 2 YEARS (older history was filtered out).

The Prosemino group chat is the day-to-day channel of the venture builder:
Marcus, Prof Dan Brett, Prof Chris Howard, Prof Paul Shearing, Hector Lancaster,
Gyen Ming Angel, Fahmida Khan, Ami Shah, Tracy Ha, Philippos and others. Treat
ALL content as PRIVATE (deal terms, cheques, personnel = visibility private).

Extract ONLY relevant signal:
- decisions, commitments, milestones for Prosemino and its ventures (Super6,
  Redoxion, Sention, Eutechtics, Element 30, Methanox, Karbana, DSV)
- fundraising / LP / corporate-partner intelligence (Centrica etc.)
- personnel changes, role clarifications, identity facts
- dated events worth a timeline entry
Ignore: logistics chatter, scheduling back-and-forth, pleasantries, memes,
links shared without comment.

For each finding, append to the relevant CANONICAL entity page (check for
compiled: frontmatter and redirects; never write to a redirect page) under a
section "## From Prosemino chat (Telegram, ingested 2026-06-12)" - create the
section once per page if absent, append bullets to it if present. One bullet
per finding, dated. Citation form: [Source: telegram:prosemino-chat YYYY-MM-DD].
Compiled pages are append-only - never restructure, never edit Facts fences.
British spelling, no em dashes.

If a finding CONTRADICTS a compiled page: do NOT rewrite the page. Append the
finding with its citation, and add one line to
/Users/marcusclover/brain/.tasks/contradiction-queue.md under the heading
"## Telegram chat finds 2026-06-12" (create the heading if absent; append-only).

Concurrency: sibling chunk agents are writing to the same pages. If an Edit
fails because the file changed, re-read and re-apply. Before adding a bullet,
check the section does not already contain a bullet for the same fact+date.

End with one counts line: chunk name, messages read, pages touched, bullets
added, contradictions queued.
