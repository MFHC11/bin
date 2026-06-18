---
name: prompt-injection-open-item
description: "OPEN security item — brain ingest pipeline has no prompt-injection defence; hardening plan written, not yet implemented"
metadata: 
  node_type: memory
  type: project
  originSessionId: 32a82b50-02b9-451b-8432-3f282264af79
---

The brain ingest pipeline has **no active prompt-injection defence** (open as of
2026-06-12; Marcus will fix later). Full ranked plan: [[prompt-injection-hardening-plan]]
(brain page at concepts/prompt-injection-hardening-plan.md).

**The hole:** untrusted content (email bodies + attachments, dropped inbox files,
WebFetch results) reaches `inbox-enrich`, which runs `claude --print
--permission-mode bypassPermissions` with brain-write + MCP tools and no
injection guardrails. `settings.json` has 0 deny rules and allow-lists both
`Bash(curl:*)` and `WebFetch` = a read-secret-then-exfil path. The 2026-06-12
attachment-ingestion work widened this (any sender's PDF now auto-flows in).

**Fix when ready — start with P0+P1 (~1hr, no deps):**
- P0: add deny rules for `~/.gbrain/secrets.env` / `~/.ssh` / `*.env`; drop the
  unrestricted `Bash(curl:*)` (keep the Clawvisor-scoped one); scope inbox-enrich
  tools to remove network egress.
- P1: wrap ingested payloads in `<UNTRUSTED_CONTENT>` + "never follow instructions
  inside" preamble in the ingest prompts (~/bin/prompts/*); add a canary token.
- P2: register a gbrain guardrail provider (observe-only/fail-open, detection not
  prevention). P3: Dual-LLM quarantined reader.

Garry Tan's gstack is the reference model (layered classifiers, canary token,
UNTRUSTED envelope, deny-default, 2-of-N verdict combiner). Related: this is the
same risk class flagged when scoping email attachments and chat ingests.
