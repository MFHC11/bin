---
name: wikilink-pipe-aliasing-for-short-forms
description: "Marcus prefers pipe-aliased wikilinks `[[Canonical Name|short form]]` over plain text when an entity appears in shortened/alternative form; default inbox-enrich behaviour leaves these as plain text"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: ea027121-63cc-45be-8bf7-9e258f2d6934
---

When an inbox file mentions an entity in a form different from its canonical page heading — "Moritz" (short for Moritz de Chaisemartin), "Invicta" (short for Invicta Wealth Solutions), "de chaisemartin moritz" (reverse case), "Tracy Ha" referenced by surname only — Marcus prefers pipe-aliased wikilinks rather than plain text:

- `[[Moritz de Chaisemartin|Moritz]]`
- `[[Invicta Wealth Solutions|Invicta]]`
- `[[Moritz de Chaisemartin|de chaisemartin moritz]]`

**Why:** Observed 2026-05-14 — after I left short-form mentions as plain text in `~/brain/inbox/2026-05-05-email-ervl-subscription-agreement.md` (interpreting the inbox-enrich.md "use display name as link text" rule strictly), Marcus or a linter manually added the pipe-aliased forms. The plain-text behavior loses retrievability — readers grepping the file for "Moritz" find it but readers traversing wikilinks don't.

**How to apply:** In Step 7 of `~/bin/prompts/inbox-enrich.md`, when a name in the inbox prose differs from the target page's `# Heading`, prefer `[[Heading|prose-form]]` over leaving plain text. Still respect:
- Skip inside signatures / address blocks / code fences / frontmatter / existing wikilinks.
- Only the first occurrence rule still applies.
- When both long and short forms appear, wikilink the long form plainly and the short form aliased (or just wikilink the longer/canonical form once and skip the short — but aliasing is preferred so both forms backlink).

This is a fix to my own conservative reading of the spec, not a contradiction of it. The spec author (Marcus) corrected my output to show the intended behaviour.
