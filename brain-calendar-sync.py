#!/usr/bin/env python3
"""brain-calendar-sync — sync Google Calendar to ~/brain/daily/calendar/.

Writes one markdown file per day:
  ~/brain/daily/calendar/YYYY/YYYY-MM-DD.md

Each daily file's `## Calendar` section is rewritten on every sync; any other
sections (## Notes, ## Prep, etc.) are preserved verbatim. Manual content
survives.

Default window: last 7 days through next 14 days (rolling).
Override with --start YYYY-MM-DD --end YYYY-MM-DD.

Reads env from keychain via the master 9 AM script.
"""
from __future__ import annotations
import datetime as dt
import json
import os
import re
import sys
from pathlib import Path
from collections import defaultdict

sys.path.insert(0, str(Path(__file__).parent))
from _clawvisor import gateway_request  # noqa: E402

CAL_SERVICE = "google.calendar:marcus@erv.io"

BRAIN = Path.home() / "brain"
CAL_ROOT = BRAIN / "daily/calendar"
RAW_DIR = CAL_ROOT / ".raw"
INTEGRATION_DIR = Path.home() / ".gbrain/integrations/calendar-to-brain"
HEARTBEAT_FILE = INTEGRATION_DIR / "heartbeat.jsonl"

NOW_ISO = dt.datetime.utcnow().strftime("%Y-%m-%dT%H:%M:%SZ")

# ─── Helpers ──────────────────────────────────────────────────────────────────

def _heartbeat(status: str, details: dict):
    HEARTBEAT_FILE.parent.mkdir(parents=True, exist_ok=True)
    with HEARTBEAT_FILE.open("a") as f:
        f.write(json.dumps({"ts": NOW_ISO, "event": "sync",
                            "status": status, "details": details}) + "\n")


def parse_args() -> tuple[str, str]:
    today = dt.date.today()
    start = today - dt.timedelta(days=7)
    end = today + dt.timedelta(days=14)
    args = sys.argv[1:]
    for i, a in enumerate(args):
        if a == "--start" and i + 1 < len(args):
            start = dt.date.fromisoformat(args[i + 1])
        elif a == "--end" and i + 1 < len(args):
            end = dt.date.fromisoformat(args[i + 1])
    return start.isoformat(), end.isoformat()


def fetch_events(start_iso: str, end_iso: str) -> list[dict]:
    """Pull events via ClawVisor list_events. Window: [start, end] inclusive."""
    iso_from = f"{start_iso}T00:00:00Z"
    iso_to = f"{end_iso}T23:59:59Z"
    all_events: list[dict] = []
    page_token = None
    safety = 30  # don't loop forever
    while safety > 0:
        safety -= 1
        params = {
            "from": iso_from,
            "to": iso_to,
            "max_results": 250,
            "order_by": "startTime",
            "single_events": True,
        }
        if page_token:
            params["page_token"] = page_token
        result = gateway_request(
            CAL_SERVICE, "list_events", params,
            reason=f"Daily 9 AM brain-ingestion: enumerate Google Calendar events in window "
                   f"{start_iso} to {end_iso} for filing under ~/brain/daily/calendar/.",
        )
        # ClawVisor's google.calendar adapter returns `data` as a flat list of
        # events (not a dict wrapping them). Pagination cursor — if any — lives
        # under `meta`.
        data = result.get("data", [])
        if isinstance(data, list):
            events = data
        else:
            events = data.get("events") or data.get("items") or []
        all_events.extend(events)
        meta = result.get("meta", {})
        page_token = meta.get("next_page_token")
        if not page_token:
            break
    return all_events


# ─── Event formatting ─────────────────────────────────────────────────────────

def parse_event_date(ev: dict) -> str | None:
    """Return YYYY-MM-DD or None for cancelled events.

    ClawVisor's calendar adapter gives `start` and `end` as ISO 8601 strings
    directly (e.g. "2026-05-12T11:30:00+01:00" or "2026-05-12" for all-day).
    Fall back to Google API's `{date,dateTime}` shape just in case.
    """
    if (ev.get("status") or "").lower() == "cancelled":
        return None
    start = ev.get("start")
    if isinstance(start, str):
        return start[:10]
    if isinstance(start, dict):
        s = start.get("date") or start.get("date_time") or start.get("dateTime")
        return s[:10] if s else None
    return None


def _start_iso(ev: dict) -> str | None:
    """Pull a comparable start ISO string regardless of shape."""
    s = ev.get("start")
    if isinstance(s, str):
        return s
    if isinstance(s, dict):
        return s.get("date_time") or s.get("dateTime") or s.get("date")
    return None


def _end_iso(ev: dict) -> str | None:
    e = ev.get("end")
    if isinstance(e, str):
        return e
    if isinstance(e, dict):
        return e.get("date_time") or e.get("dateTime") or e.get("date")
    return None


def format_time(iso_str: str | None) -> str:
    if not iso_str or "T" not in iso_str:
        return "all-day"
    try:
        # Take HH:MM after T
        t = iso_str.split("T", 1)[1][:5]
        return t
    except Exception:
        return "all-day"


ATTENDEE_BLOCKLIST = ("@resource.calendar.google.com", "@group.calendar.google.com")


def filter_attendees(attendees: list[dict]) -> list[str]:
    out = []
    for a in attendees or []:
        if not isinstance(a, dict):
            continue
        # Skip self (the user is implicit)
        if a.get("self"):
            continue
        email = (a.get("email") or "").lower()
        if any(b in email for b in ATTENDEE_BLOCKLIST):
            continue
        name = a.get("display_name") or a.get("displayName") or a.get("name")
        if not name:
            name = (a.get("email") or "").split("@")[0]
        if name and name.startswith("YC-SF-"):
            continue
        if name:
            out.append(name)
    return out


def format_event_line(ev: dict) -> str | None:
    """Format one event as a markdown bullet, or None to skip."""
    if (ev.get("status") or "").lower() == "cancelled":
        return None
    start_iso = _start_iso(ev)
    end_iso = _end_iso(ev)
    is_all_day = "T" not in (start_iso or "")

    title = (ev.get("summary") or ev.get("title") or "(no title)").strip()
    location = (ev.get("location") or "").strip()
    attendees = filter_attendees(ev.get("attendees") or [])

    cal_label = ""  # ClawVisor result may not carry calendar id directly; leave blank

    time_str = "all-day" if is_all_day else f"{format_time(start_iso)}-{format_time(end_iso)}"
    parts = [f"- **{time_str}**", f"**{title}**"]
    if cal_label:
        parts.append(f"({cal_label})")
    if location:
        parts.append(f"📍 {location}")
    if attendees:
        parts.append("— with " + ", ".join(attendees[:8]))
    return " ".join(parts)


def write_daily_file(date_str: str, events: list[dict]):
    """Write daily file, preserving any non-Calendar sections."""
    year = date_str[:4]
    dir_ = CAL_ROOT / year
    dir_.mkdir(parents=True, exist_ok=True)
    path = dir_ / f"{date_str}.md"

    # Sort: all-day first, then by start time
    def sort_key(ev):
        iso = _start_iso(ev) or ""
        return ("T" in iso, iso)
    events_sorted = sorted(events, key=sort_key)

    lines: list[str] = []
    for ev in events_sorted:
        line = format_event_line(ev)
        if line:
            lines.append(line)

    calendar_section = "## Calendar\n\n" + ("\n".join(lines) if lines else "_no events_") + "\n"

    if path.exists():
        existing = path.read_text()
        # Replace ONLY the `## Calendar` section, preserve everything else
        if "## Calendar" in existing:
            before = existing.split("## Calendar")[0]
            # find next `## ` heading after Calendar
            tail_match = re.search(r"\n##\s+(?!Calendar)", existing[existing.find("## Calendar") + 1:])
            if tail_match:
                tail_start = existing.find("## Calendar") + 1 + tail_match.start() + 1
                after = existing[tail_start:]
                content = before.rstrip("\n") + "\n\n" + calendar_section + "\n" + after
            else:
                content = before.rstrip("\n") + "\n\n" + calendar_section
        else:
            content = calendar_section + "\n---\n\n" + existing
    else:
        # Fresh file: just the Calendar section with date heading
        weekday = dt.date.fromisoformat(date_str).strftime("%A")
        content = f"# {date_str} ({weekday})\n\n{calendar_section}"

    path.write_text(content)


# ─── Main ─────────────────────────────────────────────────────────────────────

def main():
    start_iso, end_iso = parse_args()
    print(f"[calendar-sync] window {start_iso} → {end_iso}", file=sys.stderr)

    INTEGRATION_DIR.mkdir(parents=True, exist_ok=True)
    CAL_ROOT.mkdir(parents=True, exist_ok=True)
    RAW_DIR.mkdir(parents=True, exist_ok=True)

    try:
        events = fetch_events(start_iso, end_iso)
    except RuntimeError as e:
        print(f"[calendar-sync] FATAL: {e}", file=sys.stderr)
        _heartbeat("error", {"error": str(e), "window": f"{start_iso}..{end_iso}"})
        sys.exit(1)

    # Preserve raw response for provenance
    raw_path = RAW_DIR / f"events-{start_iso}_{end_iso}.json"
    raw_path.write_text(json.dumps(events, indent=2)[:5_000_000])  # 5MB cap

    # Group by date
    by_date: dict[str, list[dict]] = defaultdict(list)
    for ev in events:
        d = parse_event_date(ev)
        if d:
            by_date[d].append(ev)

    # Walk every date in window, even empty days (overwrite Calendar section
    # to clear stale events)
    start = dt.date.fromisoformat(start_iso)
    end = dt.date.fromisoformat(end_iso)
    cur = start
    files_written = 0
    while cur <= end:
        ds = cur.isoformat()
        write_daily_file(ds, by_date.get(ds, []))
        files_written += 1
        cur += dt.timedelta(days=1)

    print(f"[calendar-sync] {len(events)} events across {len(by_date)} days; wrote {files_written} daily files", file=sys.stderr)
    _heartbeat("ok", {"events": len(events), "days_with_events": len(by_date),
                      "files_written": files_written,
                      "window": f"{start_iso}..{end_iso}"})


if __name__ == "__main__":
    main()
