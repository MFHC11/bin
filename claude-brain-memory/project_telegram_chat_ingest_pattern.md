---
name: telegram-chat-ingest-pattern
description: Reusable pipeline for ingesting group-chat exports (Telegram/WhatsApp) into the brain without stub pollution — splitter script + tiered agent fleet
metadata: 
  node_type: memory
  type: project
  originSessionId: 32a82b50-02b9-451b-8432-3f282264af79
---

Pattern proven on the "ERV Deal Flow" Telegram export (8,917 msgs, 2022–2026), ingested 12 Jun 2026.

**Pipeline:** (1) entity-keyword splitter with reply-chain tag inheritance — script kept at `~/brain/.tasks/telegram-deal-flow/split.py` (entity map is the curated part; regex per entity, case-sensitive for ambiguous short names); (2) tiered fleet: ≥10 msgs + real page → enrichment agent appends `## Deal flow history (Telegram)` to canonical page; everything else → batch pass-extraction agents returning structured one-liners (7 threads/agent, each writes its own pass-batch-N.md to avoid write conflicts); (3) governor compiles `deals/erv-deal-flow-passes.md` (anti-portfolio register); (4) one agent reads all >450-char messages → `concepts/erv-deal-flow-technical-insights.md`; (5) selective PDF queue to brain-pdf-worker; raw export archived to `sources/telegram/` (gitignored).

**Why:** Marcus explicitly wants no thin stubs from chat ingests — sub-threshold companies get one line on the passes register, never their own page. Citation form: `[Source: telegram:erv-deal-flow YYYY-MM-DD]`.

**Gotchas:** Attio stub pages match slugs but aren't canonical (blixt.md stub vs [[blixt-tech]] real page — resolve canonical targets by file size before dispatch); keyword false positives are common (Gyen = a person; "Volta"/"Jupiter"/"Emerald" threads ~80% noise) — agents must be told to filter and pass-extractors must support a not-a-deal status.
