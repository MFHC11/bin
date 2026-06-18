---
name: zsh tied variables — never use `local path` or other PATH-tied names
description: In zsh scripts (Marcus's ~/bin/), avoid lowercase `path`/`cdpath`/`manpath`/`fpath` as local variable names — they silently corrupt $PATH for the function's lifetime
type: feedback
originSessionId: 9a9587e0-e211-4e8d-a602-02e0bccf38e9
---
In **zsh** (which Marcus's ~/bin/ scripts use exclusively), several lowercase variables are *tied* to their uppercase counterparts as arrays:

| lowercase (array) | tied to | effect of `local NAME="..."` |
|---|---|---|
| `path` | `PATH` | corrupts command lookup |
| `cdpath` | `CDPATH` | breaks `cd` |
| `manpath` | `MANPATH` | breaks `man` |
| `fpath` | `FPATH` | breaks autoload |
| `mailpath` | `MAILPATH` | breaks mail |
| `fignore` | `FIGNORE` | (less destructive) |

`status` is also read-only in zsh (alias for `$?`). `local status=...` will fail with "read-only variable: status".

**Why:** Burned an hour on `assert_file_contains` failing with `command not found: grep` despite `/usr/bin` being in `$PATH`. Root cause: `local path="$1"` inside the function rewrites `$PATH` to the single string of the file path, so `grep` becomes unfindable until the function returns. Sister function `assert_log_contains` worked fine because it used `local file=...`.

**How to apply:**
- In any zsh function under `~/bin/`, never use `local path` — use `local file`, `local target`, `local fpath_arg`, etc.
- Same for the other tied names above.
- Never use `local status` — use `local rc`, `local exit_code`, or `local porcelain_lines`.
- If you see a `command not found` error inside a function for a binary that obviously exists, suspect a tied-variable shadow first.
