---
name: no-em-dashes
description: "Marcus bans em dashes (—) in ALL writing produced for him — drafts, briefings, brain pages, emails"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 32a82b50-02b9-451b-8432-3f282264af79
---

Never use em dashes (—) in writing produced AS OUTPUT for Marcus: LP drafts, briefings, emails, summaries, and freshly-drafted prose/enrichment.

**Scope clarification (2026-06-14):** The ban is on *drafted output*, NOT on content already stored in the brain. Marcus: "I don't mind em dashes stored in the brain, it's just when I ask the brain or agents to draft something for me as output my writing needs to exclude em dashes." So do NOT retroactively scrub em dashes from old brain pages; only enforce the rule on new output you generate. (During the 2026-06-14 inbox sweep, em-dash hits in pre-2026-06-12 brain lines were correctly left untouched.)

**Why:** Marcus flagged the 2026-06-12 Tobe Energy LP draft (David Velasquez) as "riddled with em dashes". Em dashes read as AI-generated tells in his external communications.

**How to apply:** Use a comma, colon, parentheses, or split into two sentences instead. En dashes in numeric ranges (350–700 bar) are fine. The rule is also embedded in [[telegram-chat-ingest-pattern]]-style skill prompts: ~/bin/prompts/lp-follow-up-email.md, sunday-briefing.md, inbox-enrich.md, pdf-to-brain.md, and the user CLAUDE.md. When spawning writing subagents, copy the ban into their prompts.
