---
name: Don't deprecate working scripts until a week of green replacements
description: When migrating brain-* tooling, keep old scripts (brain-eod, cal-mail-weekly-sync, brain-sync) alive until the replacement has run cleanly for at least 7 days
type: feedback
originSessionId: 9a9587e0-e211-4e8d-a602-02e0bccf38e9
---
When migrating shell tooling in `~/bin/`, **do not delete or deprecate the old script until the replacement has been running cleanly for ≥1 week**.

**Why:** Marcus stated this rule explicitly during the brain-run consolidation kickoff. The brain pipeline is load-bearing for his daily workflow and one bad migration loses real work (Granola transcripts, Gmail watermark drift, missed enrichment). A week of green runs is the bar for confidence; reverting from a known-good old script is essentially free, while reconstructing lost state is not.

**How to apply:**
- Don't `rm` or `mv` the old script in the same session that builds the new one
- Don't replace the existing Automator buttons until the new buttons have been used cleanly
- Mark old scripts deprecated (in comments or with a `# DEPRECATED — use brain-run` banner) but leave them executable
- Schedule the cleanup as a follow-up after a quoted "if green for 7 days, remove" condition
- Applies generally to any production script migration in `~/bin/`, not just brain-*
