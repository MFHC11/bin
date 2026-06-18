---
name: project_gbrain_brainstorm_usage
description: "How to run gbrain brainstorm/lsd cleanly — env key, save flags, display threshold, resume gotcha, grounding limits"
metadata: 
  node_type: memory
  type: project
  originSessionId: e679b786-ec3c-4a1c-a7d8-9ed8e43643da
---

Operational notes for `gbrain brainstorm` (sober, far-bank 6, --save default ON) and `gbrain lsd` (Lateral Synaptic Drift, inverted judge, far-bank 12, --save default OFF).

- **Env key:** both need `ANTHROPIC_API_KEY`. It's in `~/.gbrain/secrets.env` but NOT exported into a fresh non-interactive shell, so a bare run fails with "Anthropic chat requires ANTHROPIC_API_KEY". Prefix every run with `set -a; source ~/.gbrain/secrets.env; set +a`. Same class of issue as [[feedback_macos_cron_keychain]].
- **`0 of N` is a display threshold, not a failure.** Console prints e.g. "Ideas (0 of 94)" when nothing clears the surface bar, but the saved file in `wiki/ideas/YYYY-MM-DD-{brainstorm,lsd}-<slug>.md` contains ALL N ideas with scores + judge notes. Always read the file, not the console.
- **`--resume <run_id>` rarely works:** lsd re-samples close/far sets every invocation, so inputs (and the derived run_id) change → "does not match inputs". A judge-phase crash (e.g. Anthropic "Overloaded") loses the ideas. Pass `--save` so at least the generated ideas persist before the judge runs.
- **Grounding:** bisociation crosses YOUR notes. The brain is an energy-VC / Fund II fundraising corpus with ~nothing on GPU/datacenter/compute, so an off-domain technical question makes the close-set fall back to LPs (Setter Capital, US Army) and most crosses score 1.00 as honest "won't fabricate" refusals. Real value comes from (a) topic-grounded questions inside the corpus, or (b) the few crosses that hit `concepts/electrochemistry-green-energy` or `projects/erv-shareholder-update-*` and connect the actual ERV portfolio to the question.
- **Cost (actuals seen):** brainstorm ~$0.32, lsd ~$0.47 per run; estimates print ~2-3x high because failed/refused crosses cost less.
