---
name: feedback_brain_sync_doctor_exit
description: "brain-sync \"fails\" (exit 1) at the health-check step when gbrain doctor is below threshold — benign, not a sync failure"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: b5395f9c-baf8-436e-b698-a2b89b437f7f
---

`~/bin/brain-sync` runs `set -euo pipefail` and its final Step 4 does `DOCTOR=$(gbrain doctor --json ...)`. **`gbrain doctor` exits non-zero (1) whenever overall health is below threshold** — which it currently is due to the `[FAIL] orphan_ratio` (89% of pages have no inbound links). So `set -e` aborts brain-sync at the health check with **exit 1, AFTER all real work (git commit + push, gbrain sync, embed) has already succeeded.**

**Why it matters / how to apply:** a "brain-sync failed (exit 1)" notification is almost certainly this — verify the real work landed (git `HEAD == origin/main`, working tree clean, "Pushed N files" + "Embeddings up to date" in the log) before treating it as a failure. It will keep happening every manual brain-sync run until the orphan_ratio FAIL is resolved (see `~/brain/.tasks/orphan-ratio-entity-linking.md` → `gbrain extract links --by-mention`). Optional permanent fix: stop brain-sync gating on `gbrain doctor`'s exit code (it's a health report, not a sync error). Related: [[project_gbrain_dream_1570_race]].
