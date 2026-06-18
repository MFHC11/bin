---
name: brain-sync-zero-pages-indexed
description: "brain-sync \"0 new pages indexed\" can be misleading — pages may still be live in the DB; verify with get_page/get_backlinks"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 12265b90-6ebb-4ec7-ae62-edf9d2a65b52
---

`brain-sync` Step 2 ("Syncing to Supabase") can print `✓ 0 new pages indexed` and Step 3 `Embedded 0 chunks` even when brand-new pages WERE ingested. Confirmed 2026-06-08 creating `companies/oort-energy/investor-bridge` + `companies/basf`: the counter said 0, but `get_page` returned the page (created_at matched the sync time) and `get_backlinks` resolved both directions.

**Why:** the "new pages" counter tracks a different diff than what actually gets ingested; pages appear in the DB at/around write time regardless of the count.

**How to apply:** don't read "0 new pages indexed" as proof of failure — verify ingestion with `get_page` / `get_backlinks` against the brain DB. Complements [[feedback_brain_sync_doctor_exit]].
