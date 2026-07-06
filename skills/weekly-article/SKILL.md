---
name: weekly-article
description: >
  The weekly article-drafting loop: score the idea backlog, pick with Marcus (or
  auto-pick headless), retrieve evidence from the brain, draft via article-persona,
  critic-pass, deliver a markdown draft, and update pipeline state. Use when asked
  for "weekly article", "draft this week's article", "run the article loop",
  "what should I write this week", or when the scheduler fires it.
triggers:
  - "weekly article" / "article loop" / "what should I write this week"
  - "draft this week's post/blog"
  - scheduled headless run via ~/bin/weekly-article --headless
authoritative_instructions: ~/bin/prompts/weekly-article.md (read fresh each run)
voice_contract: ~/bin/skills/article-persona/SKILL.md (drafting + critic pass)
backlog: concepts/erv-content-ideas (DB-only page; read/write via MCP or gbrain CLI)
output: ~/brain/drafts/articles/YYYY-MM-DD-<idea-id>-<slug>.md
ledger: ~/brain/.tasks/skill-evolution/weekly-article/ledger.jsonl
model_default: frontier (public compiled writing; governor routes drafting frontier)
headless: step (b) confirmation degrades to auto-pick-top-with-rationale
---

# Weekly Article Loop

One command, six steps: locate backlog, score and pick (confirm with Marcus when
interactive), retrieve evidence with source slugs, draft with the article-persona
skill, critic-pass, deliver the file and mark the idea in-progress.

The full step-by-step contract lives in ~/bin/prompts/weekly-article.md; read it
fresh every run, do not work from memory of it. The voice and critic contract lives
in ~/bin/skills/article-persona/SKILL.md.

Hard rules that survive any summarisation: no em dashes anywhere; nothing non-public
in a draft (anchor name never); never invent specifics, placeholder them; the critic
pass is mandatory before delivery; the run log on the backlog page is the variety
guard, keep it current.
