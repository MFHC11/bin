---
name: feedback_exhaust_transcripts_before_gating
description: Read the FULL meeting transcript (incl. .transcripts/ sidecars) before asking Marcus for meeting context; the lp-follow-up-email gate should only ask for genuinely absent info
metadata: 
  node_type: memory
  type: feedback
  originSessionId: cfbd9c84-836f-483e-b1ea-5eff34dd7d1b
---

2026-07-07, drafting the CMA CGM follow-up: I asked Marcus "what was agreed at the end of the call?" for the third email in a row, and he pushed back: "Why do you keep asking me this question. This is all in the granola transcript." I had read the transcript selectively (grep filters, first N lines) and wrongly assumed the wrap-up was beyond the 200-utterance capture.

**Why:** the clarification gate in ~/bin/prompts/lp-follow-up-email.md is meant to surface gaps, not outsource reading. Asking for facts that sit in an available transcript wastes Marcus's time and erodes trust in the gate.

**How to apply:** before running the gate for any post-meeting email, read the ENTIRE meeting note AND its full-transcript sidecar (meetings/granola/.transcripts/<stem>.txt, added 2026-07-07). Extract next steps, asks, and objections from there. Only ask Marcus when the information is genuinely absent (e.g. transcript truncated before the close), and say explicitly what was checked ("the recording ends at X, so..."). Related: [[project_weekly_article_system]] is unrelated; see [[project_gbrain_link_graph_bugs]] for the sidecar fix provenance.
