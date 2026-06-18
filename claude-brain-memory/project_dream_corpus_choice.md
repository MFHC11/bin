---
name: project_dream_corpus_choice
description: "Which corpus actually feeds the gbrain dream synthesis well — session transcripts are low-yield, meetings/notes are richer"
metadata: 
  node_type: memory
  type: project
  originSessionId: 8af903db-9ea0-4a12-a0a8-5407af023b9c
---

The dream synthesize phase mines REFLECTIVE conversations (new ideas, theses, self-patterns, decisions about people/companies). Marcus's Claude Code session transcripts are overwhelmingly task-execution (inbox-enrich, briefings, debugging) which the Haiku judge correctly rejects as "routine ops" — yield is ~30-40% on a thinking day, near 0 on ops-heavy days.

Higher-yield corpora for synthesis:
- **Granola meeting transcripts** = richest input (LP / portfolio / co-investor meetings carry the real strategic content). gbrain has a separate `dream.synthesize.meeting_transcripts_dir` config key built for exactly this; pair with the granola skill to export meetings into a dir.
- **Voice memos / Wispr notes** = pure-signal reflections, high worth-rate.
- Session transcripts = keep as a low-cost secondary feed; the judge filters noise honestly and occasionally catches a gem (e.g. the Marco Nix network-mapping page).

Also: synthesize writes to `wiki/originals/` + `wiki/personal/reflections/`, NOT to entity pages. Verified nightly entity-enrichment levers (2026-05-29):
- `extract` (deterministic, no key) — materializes wikilinks + timeline into the graph. PROVEN: a new reflection's links wired onto entity pages (e.g. people/chris-oshea gained a backlink). This is the real connectivity lever; fires every cycle.
- `extract_facts` — fires (scanned 10,115 pages) but inserts 0 because the brain uses `## Compiled Truth` + timeline, NOT the `## Facts` fence it reconciles. No-op on this data model, not broken.
- `patterns` — LLM, gated at ≥3 reflections in last 30d; skips until synthesis accrues enough. Activates over time.
- The primary entity-enrichment engine remains the inbox-enrich pipeline (compiled_truth + timeline + gmail citations). See [[project_dream_cycle_synthesis_fix]].
