#!/usr/bin/env bash
# wispr-sync: pull new Wispr Flow notes from GitHub into ~/brain/inbox/
# Matches the pattern in brain-daily-9am.sh: set -u (not -e), JSONL heartbeat,
# tee-to-shared-log. Dedup state stored at ~/.gbrain/integrations/wispr-notes/state.json.

set -u

PATH="$HOME/.bun/bin:$HOME/.local/bin:$HOME/bin:/usr/local/bin:/usr/bin:/bin"
export PATH

INTEGRATION_ID="wispr-notes"
NOTES_REPO_URL="git@github.com:MFHC11/wispr-notes.git"
LOCAL_CLONE="$HOME/brain/.wispr-notes"
INBOX="$HOME/brain/inbox"
STATE_DIR="$HOME/.gbrain/integrations/$INTEGRATION_ID"
STATE_FILE="$STATE_DIR/state.json"
HEARTBEAT_FILE="$STATE_DIR/heartbeat.jsonl"
LOG_DIR="$HOME/.gbrain/cron"
LOG_FILE="$LOG_DIR/brain-$(date +%F).log"

mkdir -p "$STATE_DIR" "$LOG_DIR" "$INBOX"

log() {
    printf '[%s wispr-sync] %s\n' "$(date '+%H:%M:%S')" "$*" | tee -a "$LOG_FILE" >&2
}

heartbeat() {
    local status="$1" details="${2:-{}}"
    printf '{"ts":"%s","event":"sync","status":"%s","details":%s}\n' \
        "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$status" "$details" \
        >> "$HEARTBEAT_FILE"
}

# --- Clone or fast-forward pull ---
if [ ! -d "$LOCAL_CLONE/.git" ]; then
    log "first run: cloning $NOTES_REPO_URL into $LOCAL_CLONE"
    if ! git clone "$NOTES_REPO_URL" "$LOCAL_CLONE" >>"$LOG_FILE" 2>&1; then
        log "clone failed (is the repo created and SSH key authorized?)"
        heartbeat "error" '{"phase":"clone"}'
        exit 1
    fi
else
    if ! git -C "$LOCAL_CLONE" pull --ff-only >>"$LOG_FILE" 2>&1; then
        log "pull failed (non-fast-forward or auth issue)"
        heartbeat "error" '{"phase":"pull"}'
        exit 1
    fi
fi

# --- Process new files in Python (clean JSON state + slug rewrite) ---
python3 - "$LOCAL_CLONE" "$INBOX" "$STATE_FILE" "$HEARTBEAT_FILE" <<'PY'
import json
import re
import shutil
import sys
from datetime import datetime, timezone
from pathlib import Path

clone, inbox, state_file, heartbeat_file = sys.argv[1:5]
notes_dir = Path(clone) / "notes"
state_path = Path(state_file)
inbox_path = Path(inbox)

state = {"known_ids": [], "last_sync": None}
if state_path.exists():
    try:
        state = json.loads(state_path.read_text() or "{}")
    except json.JSONDecodeError:
        pass
    state.setdefault("known_ids", [])
known = set(state["known_ids"])


def slugify(s: str, max_len: int = 60) -> str:
    s = re.sub(r"[^\w\s-]", "", s, flags=re.UNICODE).strip().lower()
    s = re.sub(r"[\s_]+", "-", s)
    s = re.sub(r"-+", "-", s)
    return s[:max_len].strip("-") or "untitled"


def extract_title(md: str) -> str:
    for line in md.splitlines():
        if line.startswith("# "):
            return line[2:].strip()
    return "untitled"


new_count = 0
errors = 0
if notes_dir.exists():
    for md in sorted(notes_dir.glob("*.md")):
        if md.name in known:
            continue
        try:
            body = md.read_text()
            date_prefix = md.name[:10] if re.match(r"\d{4}-\d{2}-\d{2}", md.name) else datetime.now(timezone.utc).strftime("%Y-%m-%d")
            slug = slugify(extract_title(body))
            dest = inbox_path / f"{date_prefix}-wispr-{slug}.md"
            n = 1
            while dest.exists():
                dest = inbox_path / f"{date_prefix}-wispr-{slug}-{n}.md"
                n += 1
            shutil.copy2(md, dest)
            known.add(md.name)
            new_count += 1
        except Exception as e:
            print(f"error processing {md.name}: {e}", file=sys.stderr)
            errors += 1

state["known_ids"] = sorted(known)[-2000:]
state["last_sync"] = datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")
state_path.parent.mkdir(parents=True, exist_ok=True)
state_path.write_text(json.dumps(state, indent=2))

print(f"copied {new_count} new file(s), {errors} error(s)")

hb = {
    "ts": state["last_sync"],
    "event": "sync",
    "status": "ok" if errors == 0 else "partial",
    "details": {"new": new_count, "errors": errors},
}
with open(heartbeat_file, "a") as f:
    f.write(json.dumps(hb) + "\n")
PY

PY_EXIT=$?
if [ $PY_EXIT -ne 0 ]; then
    log "python phase failed with exit $PY_EXIT"
    heartbeat "error" "{\"phase\":\"process\",\"exit\":$PY_EXIT}"
    exit $PY_EXIT
fi

log "sync complete"
