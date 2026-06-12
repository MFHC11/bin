# pdf-to-brain — authoritative prompts (tuning surface)

These are the canonical prompts for the `pdf-to-brain` pipeline. v1 mirrors them as the
`PER_PAGE_PROMPT` and `SYNTH_PROMPT` constants in `~/bin/pdf-to-brain`. To iterate prompt
quality, edit here and the matching constant in the script, then bump `PROMPT_VERSION` in the
script to invalidate the per-page cache. (Read fresh each run.)

Design intent: plain extraction transcribes a figure; this pipeline must capture what the
figure ARGUES. The per-page pass states the takeaway; the synthesis pass produces the
doc-level "so what".

---

## Per-page vision prompt (model: sonnet)

Variables: `{image_path}`, `{page_no}`, `{total}`, `{page_text}` (the page's pdftotext
extraction, truncated ~6000 chars, supplied as grounding only).

```
Read the image file at {image_path} using the Read tool. It is slide {page_no} of {total}
from a management-consulting due-diligence deck. A raw text-layer extraction of the same
slide is provided below as grounding (accurate for text/numbers, but it does NOT capture
what charts mean).

--- TEXT LAYER (grounding only) ---
{page_text}
--- END TEXT LAYER ---

Transcribe THIS slide into structured markdown. Use the image as the source of truth for
anything visual; use the text layer to get exact spellings and numbers right. Never invent
numbers you cannot read (use "[illegible]"). Do not summarize tables — transcribe every row
and column.

Return ONLY a JSON object (no prose before or after, no markdown fences):
{"title": "<slide headline, verbatim if present>", "tables_markdown": "<every table as
GitHub-flavored markdown, or empty string if none>", "data_points": ["<quantified readings
off charts: series, units, the specific numbers/percentages>"], "body_markdown": "<any
other slide text worth keeping>", "insight": "<2-4 sentences: what does this slide ARGUE?
The takeaway, not a description of the visuals.>"}
```

Quality bar: every chart/table on the slide must yield (a) a reconstructed markdown table or
quantified data points, and (b) a 2-4 sentence insight stating the argument. Footnotes,
callouts, and management-forecast caveats must survive.

---

## Synthesis prompt (model: opus)

Variables: `{title}`, `{total}`, `{digest}` (per-slide `## Page N — title / Insight / Data`).

```
You are a partner-level analyst writing the top-of-document briefing for a knowledge base,
from per-slide notes of a consulting due-diligence deck titled "{title}" ({total} slides).
For every slide you are given its title, its argued insight, and key data points.

--- PER-SLIDE NOTES ---
{digest}
--- END NOTES ---

Return ONLY a JSON object (no prose, no fences):
{"title": "<a clean human title for this document>", "exec_summary": "<at most 200 words:
the deck's overall thesis - the asset, the recommendation/conclusion, and the load-bearing
facts>", "key_insights": ["<5-8 single-sentence, decision-relevant findings, specifics with
figures preferred, each defensible from the notes>"], "companies": ["<organisations named:
the target, competitors, advisors, acquirers>"], "people": ["<named individuals, if any>"]}
```

Quality bar: the `key_insights` must stand alone — a reader of just that block understands
the asset, the market size, and the recommendation, with figures. No padding, no two bullets
making the same point.

## Writing style (hard rule, added 2026-06-12)

NEVER use em dashes (—) anywhere in your output: not in prose, headings, bullets, or frontmatter titles. Use a comma, colon, parentheses, or two sentences instead. En dashes inside numeric ranges (e.g. 350–700 bar) are fine. If you spawn subagents that write, copy this rule into their prompts verbatim.
