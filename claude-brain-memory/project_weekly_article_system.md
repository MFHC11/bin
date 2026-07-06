---
name: project_weekly_article_system
description: "Weekly article-drafting system built 2026-07-03: article-persona voice skill + weekly-article loop; backlog is the DB-only page concepts/erv-content-ideas"
metadata: 
  node_type: memory
  type: project
  originSessionId: 3f5a68b7-258e-46cc-a0b4-380efbb7a0d7
---

Built 2026-07-03 at Marcus's request as durable, re-runnable machinery (not a one-off):

- **Voice contract:** ~/bin/skills/article-persona/SKILL.md (pre-existed in complete form; verified against spec, not overwritten). Hard rules (no em dashes, no bullets in prose, evidence-first, British spelling), AI-tell screen (bolded triplets, not-X-but-Y, throat-clearing, hedging), calibration cadences (Harford hook, Smil number, Taleb turn, Banks range), [LI] 250-400w / [BLOG] 800-1,200w templates, deliberate placeholders, confidentiality gate, mandatory critic pass that rewrites before delivery.
- **Loop contract:** ~/bin/prompts/weekly-article.md (read fresh each run) + ~/bin/skills/weekly-article/SKILL.md + runnable ~/bin/weekly-article (interactive primes a claude session; --headless does claude --print with a `MODE: headless` marker so step-b confirmation degrades to auto-pick-top-with-rationale; --dry-run tested green).
- **Backlog:** `concepts/erv-content-ideas` is DB-ONLY (written via put_page 2026-06-19, no repo file): read/write it via MCP (get_page/put_page/add_tag) or gbrain CLI, NEVER the filesystem, and never let a repo sync clobber it. ~20 ideas, themes A-E + publish-first trio, seed slugs per idea. Status convention idea -> drafting -> published lives in idea lines; `## Run log` appended to the page is the variety-guard state.
- **Registered** in ~/.claude/CLAUDE.md (WEEKLY ARTICLE SKILL section). Output to ~/brain/drafts/articles/; ledger ~/brain/.tasks/skill-evolution/weekly-article/ledger.jsonl.

**How to apply:** any "draft a post/article" request routes through article-persona; "weekly article" triggers the full loop; headless scheduling later = cron on `~/bin/weekly-article --headless` (needs a valid CLAUDE_CODE_OAUTH_TOKEN in secrets.env, see [[project_inbox_enrich_max_oauth]]). Related: [[feedback_no_em_dashes]], [[feedback_centrica_anchor_confidential]], [[feedback_portfolio_disclosure_skill]].
