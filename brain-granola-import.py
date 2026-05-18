#!/usr/bin/env python3
"""brain-granola-import — import recent Granola meetings via ClawVisor.

Writes to ~/brain/meetings/granola/<date>-<slug>.md.

Replaces (for cron purposes) the older ~/bin/granola-to-brain which reads
the local desktop cache + Granola API directly. That older script still
exists for ad-hoc manual use; this script is the cron-driven path and
uses ClawVisor so it doesn't depend on the desktop app being open.

Reads env from keychain via the master 9 AM script.
"""
from __future__ import annotations
import datetime as dt
import json
import os
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from _clawvisor import gateway_request  # noqa: E402

GRANOLA_SERVICE = "granola"
DEFAULT_LOOKBACK_DAYS = 7


def _resolve_window(argv: list[str]) -> tuple[str, str | None]:
    """Return (created_after_iso, created_before_iso_or_None).

    Flags:
      --start YYYY-MM-DD   inclusive lower bound
      --end   YYYY-MM-DD   inclusive upper bound (converted to next-day 00:00Z)
    Default: last DEFAULT_LOOKBACK_DAYS days (no upper bound).
    """
    start = end = None
    for i, a in enumerate(argv):
        if a == "--start" and i + 1 < len(argv):
            start = argv[i + 1]
        elif a == "--end" and i + 1 < len(argv):
            end = argv[i + 1]
    if start:
        after_iso = f"{start}T00:00:00Z"
    else:
        after_iso = (dt.datetime.utcnow() - dt.timedelta(days=DEFAULT_LOOKBACK_DAYS)).strftime("%Y-%m-%dT%H:%M:%SZ")
    before_iso = None
    if end:
        try:
            ed = dt.date.fromisoformat(end) + dt.timedelta(days=1)
            before_iso = f"{ed.isoformat()}T00:00:00Z"
        except Exception:
            before_iso = f"{end}T23:59:59Z"
    return after_iso, before_iso

BRAIN = Path.home() / "brain"
TARGET_DIR = BRAIN / "meetings/granola"
INTEGRATION_DIR = Path.home() / ".gbrain/integrations/granola"
HEARTBEAT_FILE = INTEGRATION_DIR / "heartbeat.jsonl"
IMPORT_LOG = Path.home() / ".gbrain/granola-imported.log"  # shared with the older script

NOW_ISO = dt.datetime.utcnow().strftime("%Y-%m-%dT%H:%M:%SZ")


def _heartbeat(status: str, details: dict):
    HEARTBEAT_FILE.parent.mkdir(parents=True, exist_ok=True)
    with HEARTBEAT_FILE.open("a") as f:
        f.write(json.dumps({"ts": NOW_ISO, "event": "import",
                            "status": status, "details": details}) + "\n")


def already_imported(note_id: str) -> bool:
    if not IMPORT_LOG.exists():
        return False
    try:
        return note_id in IMPORT_LOG.read_text().splitlines()
    except Exception:
        return False


def mark_imported(note_id: str):
    IMPORT_LOG.parent.mkdir(parents=True, exist_ok=True)
    with IMPORT_LOG.open("a") as f:
        f.write(note_id + "\n")


def slugify(text: str, max_len: int = 60) -> str:
    s = (text or "untitled").lower()
    s = re.sub(r"[^\w\s-]", "", s)
    s = re.sub(r"[-\s]+", "-", s).strip("-")
    return s[:max_len].strip("-") or "untitled"


def list_recent_meetings() -> list[dict]:
    iso_after, iso_before = _resolve_window(sys.argv[1:])
    all_meetings: list[dict] = []
    cursor = None
    safety = 10
    while safety > 0:
        safety -= 1
        params = {"created_after": iso_after, "page_size": 100}
        if iso_before:
            params["created_before"] = iso_before
        if cursor:
            params["cursor"] = cursor
        window_desc = f"after={iso_after}"
        if iso_before:
            window_desc += f" before={iso_before}"
        result = gateway_request(
            GRANOLA_SERVICE, "list_meetings", params,
            reason=f"Brain-ingestion pipeline: list Granola meetings in window "
                   f"({window_desc}) for import into ~/brain/meetings/granola/.",
        )
        # ClawVisor granola adapter returns data as a flat list of meetings.
        data = result.get("data", [])
        if isinstance(data, list):
            meetings = data
        else:
            meetings = data.get("meetings") or data.get("items") or []
        all_meetings.extend(meetings)
        meta = result.get("meta", {})
        cursor = meta.get("next_cursor")
        if not cursor:
            break
    return all_meetings


def fetch_meeting_detail(note_id: str) -> dict | None:
    try:
        result = gateway_request(
            GRANOLA_SERVICE, "get_meeting", {"note_id": note_id},
            reason="Daily 9 AM brain-ingestion: fetch Granola meeting summary, attendees, and "
                   "metadata for one specific meeting note for filing into "
                   "~/brain/meetings/granola/.",
            data_origin=f"granola:{note_id}",
        )
        data = result.get("data")
        if isinstance(data, list):
            return data[0] if data else None
        return data or None
    except RuntimeError as e:
        print(f"[granola-import] get_meeting {note_id} failed: {e}", file=sys.stderr)
        return None


def fetch_transcript(note_id: str) -> list[str]:
    try:
        result = gateway_request(
            GRANOLA_SERVICE, "get_transcript", {"note_id": note_id},
            reason="Daily 9 AM brain-ingestion: fetch verbatim transcript for a Granola "
                   "meeting to populate the Timeline section of the brain meeting file.",
            data_origin=f"granola:{note_id}",
        )
    except RuntimeError as e:
        print(f"[granola-import] get_transcript {note_id} failed: {e}", file=sys.stderr)
        return []

    data = result.get("data")
    # Possible shapes (ClawVisor adapter variation):
    #  - list of utterance dicts: [{timestamp,speaker,text}, …]
    #  - list of plain strings:   ["[12:01] foo", …]
    #  - dict with {utterances|segments|transcript|text}
    utterances = None
    if isinstance(data, list):
        utterances = data
    elif isinstance(data, dict):
        utterances = data.get("utterances") or data.get("segments")
        if utterances is None:
            text = data.get("transcript") or data.get("text") or ""
            return [line for line in text.splitlines() if line.strip()]

    out: list[str] = []
    for u in utterances or []:
        if isinstance(u, dict):
            ts = u.get("timestamp") or u.get("start") or ""
            spk = u.get("speaker") or u.get("source") or ""
            text = u.get("text") or u.get("content") or ""
            prefix = f"[{ts}] [{spk}] " if (ts or spk) else ""
            out.append((prefix + text).strip())
        else:
            out.append(str(u))
    return [line for line in out if line.strip()]


def format_meeting(meeting: dict, transcript: list[str]) -> tuple[str, str]:
    note_id = meeting.get("id") or meeting.get("note_id") or "unknown"
    title = meeting.get("title") or meeting.get("name") or "Untitled meeting"
    date_str = (meeting.get("created_at") or meeting.get("date") or "")[:10]
    if not date_str:
        date_str = dt.date.today().isoformat()

    attendees = meeting.get("attendees") or meeting.get("participants") or []
    if isinstance(attendees, list):
        att_names = []
        for a in attendees:
            if isinstance(a, dict):
                att_names.append(a.get("name") or a.get("display_name") or a.get("email") or "?")
            else:
                att_names.append(str(a))
    else:
        att_names = []

    summary = meeting.get("summary") or meeting.get("ai_summary") or ""

    duration = meeting.get("duration") or ""

    filename = f"{date_str}-{slugify(title)}.md"

    tag_set = ["granola"]
    title_lower = title.lower()
    for kw in ["erv", "blixt", "fund", "fundraising", "centrica", "anthro",
               "prep", "exco", "ops"]:
        if kw in title_lower:
            tag_set.append(kw)

    tags_json = json.dumps(sorted(set(tag_set)))

    timeline_md = "\n".join(f"- {u}" for u in transcript[:30]) if transcript else "_(transcript not available)_"

    body = f"""---
type: meeting
date: {date_str}
attendees: {", ".join(att_names) if att_names else "[no attendees]"}
duration: {duration or "?"}
tags: {tags_json}
source: granola
granola_id: {note_id}
---

## Compiled Truth

{summary.strip() if summary else f"Granola meeting: {title} with {len(att_names)} attendee(s)."}

## Timeline

{timeline_md}

## Action Items

- [ ] [Review transcript for action items]
"""
    return filename, body


def main():
    INTEGRATION_DIR.mkdir(parents=True, exist_ok=True)
    TARGET_DIR.mkdir(parents=True, exist_ok=True)

    try:
        meetings = list_recent_meetings()
    except RuntimeError as e:
        print(f"[granola-import] FATAL list_meetings: {e}", file=sys.stderr)
        _heartbeat("error", {"error": str(e)})
        sys.exit(1)

    iso_after, iso_before = _resolve_window(sys.argv[1:])
    print(f"[granola-import] {len(meetings)} meetings in window after={iso_after[:10]} before={(iso_before or 'now')[:10]}", file=sys.stderr)

    imported = 0
    skipped = 0
    for m in meetings:
        note_id = m.get("id") or m.get("note_id")
        if not note_id:
            continue
        if already_imported(note_id):
            skipped += 1
            continue
        detail = fetch_meeting_detail(note_id) or m
        transcript = fetch_transcript(note_id)
        filename, body = format_meeting(detail, transcript)
        path = TARGET_DIR / filename
        if path.exists():
            # Filename collision (rare; same date+slug): append note_id suffix
            path = TARGET_DIR / f"{path.stem}-{note_id[:8]}.md"
        path.write_text(body)
        mark_imported(note_id)
        imported += 1

    _heartbeat("ok", {"imported": imported, "skipped_already_seen": skipped,
                      "window_after": iso_after, "window_before": iso_before})
    print(f"[granola-import] imported {imported}, skipped {skipped} existing", file=sys.stderr)


if __name__ == "__main__":
    main()
