---
name: feedback-gbrain-ipv6-ddl
description: "gbrain v0.30+ dual-pool DDL fails on Marcus's Supabase project because the direct host is IPv6-only and the network has no v6; use GBRAIN_DISABLE_DIRECT_POOL=1 or the session pooler (port 5432) for DDL"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 4ccf0532-29bb-4958-86f2-f8e4fea95352
---

When gbrain (v0.30+) needs to run DDL (schema migrations, `apply-migrations`, `init --migrate-only`) on Marcus's Supabase project (ref `uiswkvvpvosodceqsset`, region `eu-west-1`), it fails with `getaddrinfo ENOTFOUND` even though the pooler is reachable.

**Why:** v0.30 introduced a dual-pool architecture (`src/core/connection-manager.ts`). Read queries go through the transaction pooler (port 6543, IPv4). DDL goes through a derived "direct" URL — for Supabase that's `db.<project-ref>.supabase.co:5432`. On the free tier that direct host is **IPv6-only** (AAAA record only, no A record). Marcus's local network has no working IPv6, so DNS resolution fails inside Node/Bun.

**How to apply:**

- For *steady-state* operations (read, search, sync, embed, dream cycle, link/timeline extract — no DDL), the kill-switch is the right durable answer. `export GBRAIN_DISABLE_DIRECT_POOL=1` is persisted in `~/.zshrc`; DDL falls back to the pooler. This is already in place.
- For a *future major version upgrade* that runs new schema migrations, the pooler can't do DDL with prepared statements off, so the kill-switch is insufficient. Use the session-mode pooler (same hostname, port **5432**) as the explicit override for that one command:
  ```bash
  GBRAIN_DIRECT_DATABASE_URL="postgresql://postgres.uiswkvvpvosodceqsset:<pw>@aws-0-eu-west-1.pooler.supabase.com:5432/postgres" \
    gbrain init --migrate-only
  GBRAIN_DIRECT_DATABASE_URL="..." gbrain apply-migrations --yes
  ```
- The password is in `~/.gbrain/config.json` under `database_url`; do not hardcode it elsewhere.
- A permanent fix would be enabling Supabase's IPv4 add-on ($4/mo as of 2025) or getting IPv6 working on the local network. Until then, the workaround above is correct.

**Where this came from:** Diagnosed on 2026-05-13 during the 0.21.0 → 0.33.1.0 upgrade. Schema went 29 → 54, 25 migrations applied. Symptom was `Schema probe/migrate failed: getaddrinfo ENOTFOUND` on every gbrain command and total failure of `gbrain init --migrate-only`. Root cause confirmed by reading `src/core/connection-manager.ts:132-162` (deriveDirectUrl).

See also [[feedback-gbrain-shell-jobs]].
