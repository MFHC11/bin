#!/usr/bin/env bash
# inbox-backfill-enriched.sh — one-shot tag every already-enriched inbox file
# with `enriched: YYYY-MM-DD` in its YAML frontmatter so future inbox-enrich
# runs skip them via Step 1.
#
# Heuristic for "already enriched": file body contains at least one [[wikilink]].
# This catches every file the 2026-05-14 parallel run touched. Misses files
# the prior runs classified as "no targets" (newsletters, internal cancellations,
# etc.) — those will get one more re-check on the next cron run, find nothing
# material, and the new Step 8 will flag them then. Acceptable.

set -euo pipefail

INBOX="$HOME/brain/inbox"
TODAY="${1:-$(TZ=Europe/London date +%Y-%m-%d)}"
COUNT=0
SKIPPED=0
ALREADY=0

shopt -s nullglob
for f in "$INBOX"/*.md; do
    base=$(basename "$f")
    if [ "$base" = "README.md" ]; then continue; fi

    if grep -q '^enriched:' "$f"; then
        ALREADY=$((ALREADY+1))
        continue
    fi

    if ! grep -q '\[\[' "$f"; then
        SKIPPED=$((SKIPPED+1))
        continue
    fi

    # Insert `enriched: <date>` just before the second `---` (closing of frontmatter).
    awk -v tag="enriched: $TODAY" '
        BEGIN { state=0 }   # 0 = before frontmatter, 1 = inside frontmatter, 2 = after closing ---
        /^---$/ {
            if (state == 0) { state=1; print; next }
            if (state == 1) { print tag; print; state=2; next }
        }
        { print }
    ' "$f" > "$f.tmp"

    # Safety: only swap if the awk output actually grew (otherwise something went wrong)
    if [ "$(wc -c < "$f.tmp")" -gt "$(wc -c < "$f")" ]; then
        mv "$f.tmp" "$f"
        COUNT=$((COUNT+1))
    else
        rm -f "$f.tmp"
        SKIPPED=$((SKIPPED+1))
    fi
done

echo "backfill date:     $TODAY"
echo "newly tagged:      $COUNT"
echo "already tagged:    $ALREADY"
echo "skipped (no wikilinks or awk no-op): $SKIPPED"
