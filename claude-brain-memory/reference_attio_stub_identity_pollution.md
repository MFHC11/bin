---
name: attio-stub-identity-pollution
description: Attio-sourced person stubs in the brain can carry a WRONG auto-merged identity — verify before enriching
metadata: 
  node_type: memory
  type: reference
  originSessionId: 12265b90-6ebb-4ec7-ae62-edf9d2a65b52
---

Attio-sourced `[stub, attio-sourced]` person pages can carry the correct email but someone else's identity: wrong `linkedin`/`twitter`/`description`/`location` plus a long junk alias list. Confirmed 2026-06-08 — `people/alex-thistlethwayte.md` had the right `alex@sarkisfund.com` but was merged with "Alex Bakir, Director BizDev @ Planet Labs, San Francisco" + ~15 random "Alex/Alexander" aliases. The stub generator matched on first-name/email-prefix and grabbed the wrong person.

**Why:** the Attio→brain stub generator over-trusts fuzzy name matches.

**How to apply:** before trusting or enriching an attio-sourced person stub, sanity-check that `linkedin`/`description`/`location` actually fit the person (cross-check the email domain and known role). Overwrite the polluted fields rather than appending around them. Related: [[feedback_wikilink_aliasing]].
