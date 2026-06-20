---
name: project_dream_cycle_synthesis_fix
description: "Why the gbrain dream-cycle synthesis silently no-op'd and the four fixes that made it write pages"
metadata: 
  node_type: memory
  type: project
  originSessionId: 8af903db-9ea0-4a12-a0a8-5407af023b9c
---

gbrain `dream` synthesize phase (v0.41.26.1) ran to exit 0 but wrote nothing. Four stacked causes, all config/setup (no gbrain code bug needing a fork; already past the v0.41.19.0 wiki-link fix):

1. **Verdict judge (orchestrator) had no Anthropic key** → `makeJudgeClient` returns null → every transcript rejected "no configured provider" → 0 worth processing → `ok` with 0 pages. The judge runs in the *orchestrator* process (whoever runs `gbrain dream`), so the dream invocation itself needs the key.
2. **Synthesis subagent (worker) had no key** → legacy path does `new Anthropic()` (subagent.ts:168) reading `process.env.ANTHROPIC_API_KEY` ONLY — it does NOT read gbrain config.json. So the *worker/supervisor* process also needs the key. Job died: "Could not resolve authentication method."
3. **`agent.use_gateway_loop = true`** routed the subagent through the AI-SDK-v6 gateway tool loop, which throws `schema is not a function`. The stable default is the legacy Anthropic-direct path. Fix: `gbrain config unset agent.use_gateway_loop` (note: `config set` rejects the key as unknown; `unset` works).
4. **`session_corpus_dir` pointed at the raw Claude Code projects dir** — discovery reads only `.txt`/`.md`, so it ingested 136 `tool-results/*.txt` noise dumps and ignored all 153 real `.jsonl` conversations. Fix: `~/bin/gbrain-export-transcripts` converts `.jsonl`→clean `.txt` into `~/.gbrain/transcripts/`; repointed corpus there.

**The clean fix (single scoping mechanism):** launch the supervisor via `gbrain-agentic` so the key is in the worker's `process.env` — that covers BOTH the orchestrator verdict (gateway reads `{...envFromConfig, ...process.env}`) AND the legacy subagent (`new Anthropic()`). Do NOT add the key to config.json (reverted) and do NOT export it into ~/.zshrc (breaks `claude` Max routing). Run dream itself via the wrapper too, or as a shell job inside the key'd supervisor (the brain-run path).

**Proven:** real-corpus `--date 2026-05-20` run judged 2/5 worth (3 correctly rejected as routine ops), wrote 3 real pages incl. `wiki/personal/reflections/2026-05-20-network-path-to-marco-nix-elia-group`. See [[project_dream_corpus_choice]].

**5th cause — RE-BROKEN 2026-06-19 (the live blocker): Anthropic API credit balance.** On gbrain 0.42.1.0, with the 4 fixes in place (key scoped via `gbrain-agentic`, `use_gateway_loop` unset, corpus refreshed via `gbrain-export-transcripts`, supervisor up with `GBRAIN_ALLOW_SHELL_JOBS=1`), every synthesis child still **permanently fails**: `400 invalid_request_error "Your credit balance is too low to access the Anthropic API"`. The synthesize subagent's `new Anthropic()` SDK path uses `ANTHROPIC_API_KEY` (the console account), which is **unfunded by design** (Max powers `claude --print` via `CLAUDE_CODE_OAUTH_TOKEN`, NOT the SDK — see [[project_inbox_enrich_max_oauth]]). So dream synthesis cannot run on Max-only: it needs EITHER a funded Anthropic console balance OR a working Max→SDK gateway (`use_gateway_loop` is disabled because it throws `schema is not a function`). Mechanical phases that don't call the model (sync, embed, extract) still work; `gbrain-agentic dream --phase sync` = ok. **Action owner: Marcus** (fund the console account or fix the gateway). Symptom to recognise fast: `dream-cycle-summaries/<date>.md` shows "Children: 0 completed, N failed/timeout. Pages written: 0" and the supervisor log shows the 400 credit error. Do NOT re-debug the 4 config fixes, they are correct; this is billing.
