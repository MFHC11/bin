---
name: workflow-args-stringified
description: "Workflow tool args can arrive as a JSON string inside the script: hardcode constants into the script body instead of relying on args"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 3f5a68b7-258e-46cc-a0b4-380efbb7a0d7
---

In the 2026-07-03 orphan-backlink-sweep, the Workflow tool's `args` parameter (passed as a proper JSON object in the tool call) still arrived in the script as a JSON-encoded STRING, so `args.total` and `args.worklistPath` were undefined. Consequence: `Math.ceil(undefined/BATCH)` = NaN, `Array.from({length: NaN})` = empty, and the fan-out silently ran 0 of 32 batches while canaries passed (agents improvised around "work list at undefined").

**Why:** the harness serialization of Workflow args is not trustworthy for structured values, and the failure is silent (a truncated run looks like a completed one).

**How to apply:** for any Workflow script, bake constants (paths, totals, dates) into the script body as literals instead of reading them from `args`. If args must be used, validate at the top: `if (typeof args !== 'object' || !args.total) throw new Error('args arrived malformed: ' + typeof args)` so the run fails loudly. After every workflow, sanity-check processed counts against the expected total before trusting the result. Related: [[project_pdf_pipeline_ingest_gap]] (same silent-partial-completion family).
