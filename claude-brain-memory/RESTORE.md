# Claude brain-memory — backup snapshot

This is a mirror of the live Claude memory store, kept here so it rides the
`~/bin` GitHub repo and survives disk loss. The live store is at:

    ~/.claude/projects/-Users-marcusclover-brain/memory/

Refreshed automatically by `~/bin/brain-backup` (and the daily). To RESTORE on a
new machine:

    rsync -a --exclude RESTORE.md <this-dir>/ \
      ~/.claude/projects/-Users-marcusclover-brain/memory/
