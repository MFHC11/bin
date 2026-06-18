---
name: project-cold-lp-outreach-attio
description: "How to run cold LP outreach from Attio + the fit_8=Cold field is noisy (warm-parked leads, miscategorised individuals)"
metadata: 
  node_type: memory
  type: project
  originSessionId: ac997cbc-aac2-4e14-a078-d443df404e5f
---

Cold-LP-outreach fan-out run 2026-06-17 over the Attio "LP Fundraising" list (api_slug `startup_fundraising_8`, list_id 67acad84-0921-43ef-a9d3-7c8cbdbaae1c). 122 leads with Lead-class `fit_8=Cold` and Status≠Passed → ~90 tailored drafts in `brain/drafts/lp-cold-outreach/2026-06-17/` (batch-00..12 + 00-INDEX-prioritisation.md). Ran as canary + 12 parallel writer subagents (offset-sliced `list-records-in-list`, deterministic ordering so offset pagination is stable).

**Key gotchas for next time:**
- `fit_8=Cold` does NOT mean never-contacted. ~25% are warm-but-parked Qualified Leads with future-dated `action`/`action_date` ("reach out after 1st close", "follow-up in 2027", "passed for now") or live threads. Cold-emailing them contradicts the file. Always check `action`/`action_date`/`status_notes` per lead and downgrade to warm-reconnect or skip.
- Genuinely-cold filter is tighter: Status=Lead + status_notes like "no interactions"/"contact attempted unsuccessfully".
- Many "company" records are actually individuals (HNWIs from "Online search") mis-typed as companies — address them as people. Worth an Attio cleanup pass.
- Attio stub pollution recurs (see [[reference_attio_stub_identity_pollution]]): e.g. Benedikt Langer auto-merged to wrong company "TOV Lending". Trust person+LinkedIn over the company field.
- "Highly unlikely according to Peter" status_notes = auto-skip.
- ~40 leads are LinkedIn-only or firm-level with no email → drafted but need contact research before send.
- High-fit leads to push via warm intro (not cold): JIMCO (via Charlotta Blixt/Ecem), Schroders (Dave Neumann), QIA (Xavi), Al Mada (live).

Writing rules followed: canonical ERV figures from `~/bin/prompts/lp-follow-up-email-corrections.md` ($13.5M Centrica anchor, $50M, 30 Jun first close), no em dashes, no NAV/MOIC/IRR, no Divigas/Ecolectro. Related: [[project_erv_priority_ledger]], [[feedback_no_em_dashes]].
