---
name: project_gbrain_dream_1570_race
description: "gbrain full dream cycle fails sync/synthesize on Supabase pooler (#1570 in-process disconnect race); run them standalone, don't roll back"
metadata: 
  node_type: memory
  type: project
  originSessionId: b5395f9c-baf8-436e-b698-a2b89b437f7f
---

On the Supabase session-pooler brain (gbrain v0.42.1.0, 1280d ZeroEntropy), a full `gbrain dream` cycle returns `status: partial` with **`sync` and `synthesize` always failing** ("No database connection: connect() has not been called"). All later phases succeed.

**Root cause:** the dream process's own `FactsQueue` fires a fire-and-forget `queueMicrotask` (`facts/queue.ts:104,234`) that calls `disconnect()` on the module DB singleton mid-cycle; `sync`/`synthesize` call `getConnection()` (`db.ts:155`) without the #1570 `withRetry`+`reconnect` wrapper, so they fail hard. It's a **pure in-process race** — stopping the supervisor/worker does NOT fix it (isolated re-run failed identically). Confirmed via the disconnect audit (`~/.gbrain/audit/db-disconnect-*.jsonl`).

**Decisions / how to apply:**
- **Do NOT roll back to 0.41.26.1** — the #1570 mitigations postdate it, so rollback is strictly worse. Stay on 0.42.1.0.
- **Reliable path = run sync/synthesize as STANDALONE single-phase invocations** (`gbrain dream --phase sync` / `--phase synthesize`), never trust them inside the full cycle. Verified: standalone sync = `ok`; standalone synthesize connects cleanly (slow on stale session corpus — give it ≥10 min).
- **No config flag** disables the fire-and-forget drain.
- The full cycle still stamps `cycle_freshness` on `partial`, so running it for the DB phases is harmless.
- Gotcha: the progress log prints `[cycle.sync] done` even on failure — "done" = step returned, not succeeded. Only the JSON `status` is authoritative.
- Gotcha (2026-07-16): standalone `--phase synthesize` OVERWRITES `dream-cycle-summaries/<date>.md` with its own auto-summary ("Children: N failed..."), clobbering any governor-written summary for that date. Write the in-session dream summary AFTER the synthesize re-run, or rewrite it afterward. Its child jobs also still fail on the exhausted gbrain API key (0 pages written), so in-session Max-plan subagents remain the real synthesis path.
- Confirmed again 2026-07-16: full cycle exit 0 but sync+synthesize failed in-cycle; standalone re-runs both clean (sync 0.6s, synthesize 61.9s).

Full ADR: `~/brain/concepts/dream-cycle-sync-synthesize-1570.md`. Upstream report draft (pending post): `~/brain/.tasks/gbrain-1570-upstream-report.md`. Related: [[feedback_gbrain_update_procedure]], [[feedback_gbrain_ipv6_ddl]], [[project_dream_corpus_choice]].
