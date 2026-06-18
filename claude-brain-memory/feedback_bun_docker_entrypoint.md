---
name: bun-docker-entrypoint
description: "oven/bun base image auto-prepends `bun` to CMD, which turns binaries into bogus script-name lookups — clear ENTRYPOINT [] when running compiled or installed CLIs like gbrain"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: ff51740c-a8b4-47a9-9633-9e7402098cac
---

When using `FROM oven/bun:1-alpine` (or any `oven/bun:*` tag) in a Dockerfile, the image's `/usr/local/bin/docker-entrypoint.sh` prepends `bun` to CMD whenever the first arg isn't resolvable on `PATH`. This silently breaks any CMD that runs a third-party Bun-installed CLI: `CMD ["gbrain", ...]` becomes `bun gbrain ...`, Bun then looks for a `gbrain` *script* in package.json and dies with `error: Script not found "gbrain"`.

**Why:** Burned 3 deploy iterations on Fly (brain-serene-field-1751, 2026-05-20) with `bun add -g`, then `bun install + bun link`, then PATH overrides — all hit the same error because the wrapper runs before PATH gets a chance. The fix is `ENTRYPOINT []` to clear the inherited wrapper, then either:
- `CMD ["bun", "run", "/opt/<pkg>/src/cli.ts", ...]` (cleanest, no link needed), or
- `CMD ["/absolute/path/to/binary", ...]` if you compiled with `bun build --compile`.

**How to apply:** Any Dockerfile that uses an `oven/bun` base AND wants to run a Bun CLI installed via clone/link/global — add `ENTRYPOINT []` before CMD. Doesn't apply if you're running `bun run <script>` from a local package.json (that's the entrypoint's happy path). Related to [[gbrain-fly-deploy]] context.
