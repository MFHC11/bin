#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.10"
# dependencies = [
#   "icalendar>=6.0",
#   "recurring-ical-events>=3.0",
#   "tzdata",
# ]
# ///
"""brain-calendar-ics-import — backfill ~/brain/daily/calendar/ from a Google
Calendar .ics export.

Reuses write_daily_file() and format_event_line() from brain-calendar-sync.py
so the on-disk format and merge-preserve behavior stay byte-identical to the
live ClawVisor-based sync.

Defaults
    Range: earliest VEVENT in the file → today + 90 days
    Local tz: Europe/London (matches X-WR-TIMEZONE in Google's export)
    Backfill mode: only writes daily files for dates that *have* events.
    (The live weekly sync handles empty-day _no events_ stubs going forward.)

Usage
    brain-calendar-ics-import.py FILE.ics [--start YYYY-MM-DD] [--end YYYY-MM-DD]
                                          [--month YYYY-MM] [--dry-run]
"""
from __future__ import annotations

import argparse
import datetime as dt
import importlib.util
import re
import sys
from collections import defaultdict
from pathlib import Path
from zoneinfo import ZoneInfo

from icalendar import Calendar
import recurring_ical_events

# Reuse the existing sync module's formatting + merge-preserving writer
_BCS_PATH = Path(__file__).resolve().parent / "brain-calendar-sync.py"
_spec = importlib.util.spec_from_file_location("bcs", _BCS_PATH)
bcs = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(bcs)  # type: ignore[union-attr]

LOCAL_TZ = ZoneInfo("Europe/London")
SELF_EMAIL = "marcus@erv.io"
ERV_DOMAINS = ("@erv.io", "@er-v.io")

# Map video-meeting URL hosts to short platform names for readable locations.
# Order matters: more specific patterns first.
_VIDEO_HOSTS = [
    ("zoom.us", "Zoom"),
    ("meet.google.com", "Google Meet"),
    ("teams.microsoft.com", "Microsoft Teams"),
    ("teams.live.com", "Microsoft Teams"),
    ("webex.com", "Webex"),
    ("whereby.com", "Whereby"),
    ("gotomeet", "GoToMeeting"),
    ("hangouts.google.com", "Google Hangouts"),
    ("calendly.com", "Calendly"),
    ("airmeet.com", "Airmeet"),
]


def _clean_location(loc: str) -> str:
    """Shorten URL-only locations to platform names; preserve physical addresses.

    "https://zoom.us/j/123?pwd=..."           → "Zoom"
    "Microsoft Teams Meeting, GGSPT (MAX 14)" → unchanged (physical room kept)
    "Google Meet (instructions in description)" → unchanged
    "https://us02web.zoom.us/... + Room 3A"   → "Zoom + Room 3A"  (best-effort)
    """
    if not loc:
        return ""
    s = loc.strip()
    # Strip naked URLs only — preserve text segments
    parts = re.split(r"\s+", s)
    cleaned: list[str] = []
    for p in parts:
        if p.startswith("http://") or p.startswith("https://"):
            host_label = next(
                (label for needle, label in _VIDEO_HOSTS if needle in p.lower()),
                None,
            )
            if host_label and host_label not in cleaned:
                cleaned.append(host_label)
            # else: drop unknown URLs entirely (probably login-protected calendar invites)
        else:
            cleaned.append(p)
    out = " ".join(cleaned).strip(" ,;")
    return out

# Titles that, when attended only by ERV-internal people (or no one),
# represent personal placeholders rather than real meetings.
# Conservative on purpose — "Standup" / "Sync" stay IN so real internal
# meetings still appear in the timeline.
_PLACEHOLDER_TITLES = {
    "block", "busy", "hold", "tentative", "ooo", "out of office",
    "wfh", "working from home", "working from london", "working from lisbon",
    "lunch", "gym", "focus", "focus block", "focus time", "deep work",
}


# ─── ICS → event-dict conversion ─────────────────────────────────────────────

def _iso(value: dt.date | dt.datetime) -> tuple[str, bool]:
    """Return (iso_string, is_all_day) for a VEVENT date/datetime value.

    All-day → "YYYY-MM-DD".
    Timed   → "YYYY-MM-DDTHH:MM:SS+offset" in Europe/London.
    """
    if isinstance(value, dt.datetime):
        if value.tzinfo is None:
            value = value.replace(tzinfo=LOCAL_TZ)
        return value.astimezone(LOCAL_TZ).isoformat(timespec="seconds"), False
    # bare date → all-day
    return value.isoformat(), True


def _attendees(comp) -> list[dict]:
    raw = comp.get("ATTENDEE")
    if raw is None:
        return []
    items = raw if isinstance(raw, list) else [raw]
    out: list[dict] = []
    for a in items:
        email = str(a).replace("mailto:", "").replace("MAILTO:", "").strip().lower()
        params = getattr(a, "params", {}) or {}
        cn = params.get("CN", "") or ""
        out.append({
            "email": email,
            "display_name": str(cn).strip(),
            "self": email == SELF_EMAIL,
        })
    return out


def to_event_dict(comp) -> dict | None:
    """Convert one icalendar VEVENT into brain-calendar-sync's event dict shape.

    Returns None if the event lacks DTSTART (malformed).
    """
    dtstart_field = comp.get("DTSTART")
    if dtstart_field is None:
        return None
    start_val = dtstart_field.dt
    end_field = comp.get("DTEND")
    end_val = end_field.dt if end_field else start_val

    start_iso, all_day = _iso(start_val)
    end_iso, _ = _iso(end_val)

    return {
        "status": str(comp.get("STATUS", "CONFIRMED")).lower(),
        "start": start_iso,
        "end": end_iso,
        "summary": str(comp.get("SUMMARY", "")).strip(),
        "location": _clean_location(str(comp.get("LOCATION", ""))),
        "attendees": _attendees(comp),
    }


# ─── Filtering ────────────────────────────────────────────────────────────────

def is_placeholder_noise(ev: dict) -> bool:
    """Personal-placeholder title with no external attendees."""
    title = ev["summary"].lower().strip()
    if title not in _PLACEHOLDER_TITLES:
        return False
    external = [
        a for a in ev["attendees"]
        if a["email"] and not any(d in a["email"] for d in ERV_DOMAINS)
    ]
    return len(external) == 0


# ─── CLI ──────────────────────────────────────────────────────────────────────

def _find_first_event_date(cal: Calendar) -> dt.date:
    earliest: dt.date | None = None
    for comp in cal.walk("VEVENT"):
        dtstart = comp.get("DTSTART")
        if dtstart is None:
            continue
        v = dtstart.dt
        d = v.date() if isinstance(v, dt.datetime) else v
        if isinstance(d, dt.date) and (earliest is None or d < earliest):
            earliest = d
    return earliest or dt.date(2020, 1, 1)


def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    p.add_argument("ics", type=Path, help="Path to .ics export file")
    p.add_argument("--start", help="YYYY-MM-DD; default = earliest event")
    p.add_argument("--end", help="YYYY-MM-DD; default = today + 90 days")
    p.add_argument("--month", help="YYYY-MM (sets start=first, end=last of that month)")
    p.add_argument("--dry-run", action="store_true",
                   help="Show counts + sample, write nothing")
    return p.parse_args()


def main() -> int:
    args = parse_args()
    if not args.ics.exists():
        print(f"[ics-import] file not found: {args.ics}", file=sys.stderr)
        return 2

    print(f"[ics-import] parsing {args.ics} ({args.ics.stat().st_size // 1024} KB)…",
          file=sys.stderr)
    with args.ics.open("rb") as f:
        cal = Calendar.from_ical(f.read())

    if args.month:
        y, m = (int(x) for x in args.month.split("-"))
        start_d = dt.date(y, m, 1)
        end_d = (dt.date(y + (m // 12), (m % 12) + 1, 1) - dt.timedelta(days=1))
    else:
        start_d = (dt.date.fromisoformat(args.start) if args.start
                   else _find_first_event_date(cal))
        end_d = (dt.date.fromisoformat(args.end) if args.end
                 else dt.date.today() + dt.timedelta(days=90))

    print(f"[ics-import] window {start_d} → {end_d}", file=sys.stderr)

    expanded = recurring_ical_events.of(cal).between(start_d, end_d)
    print(f"[ics-import] expanded {len(expanded)} VEVENT instances", file=sys.stderr)

    by_date: dict[str, list[dict]] = defaultdict(list)
    n_cancelled = n_noise = n_invalid = 0
    for comp in expanded:
        ev = to_event_dict(comp)
        if ev is None:
            n_invalid += 1
            continue
        if ev["status"] == "cancelled":
            n_cancelled += 1
            continue
        if is_placeholder_noise(ev):
            n_noise += 1
            continue
        by_date[ev["start"][:10]].append(ev)

    print(
        f"[ics-import] {len(by_date)} dates with events; "
        f"skipped {n_cancelled} cancelled, {n_noise} placeholder-noise, "
        f"{n_invalid} invalid",
        file=sys.stderr,
    )

    if args.dry_run or not by_date:
        sorted_dates = sorted(by_date.keys())
        sample = sorted_dates[:3] + sorted_dates[-3:]
        for ds in dict.fromkeys(sample):  # de-dup while preserving order
            print(f"\n── {ds} ({dt.date.fromisoformat(ds).strftime('%A')}) "
                  f"— {len(by_date[ds])} event(s) ──", file=sys.stderr)
            for ev in sorted(by_date[ds],
                             key=lambda e: ("T" in e["start"], e["start"])):
                line = bcs.format_event_line(ev)
                if line:
                    print(line, file=sys.stderr)
        if args.dry_run:
            print(f"\n[ics-import] DRY RUN — no files written", file=sys.stderr)
        return 0

    written = 0
    for ds in sorted(by_date):
        bcs.write_daily_file(ds, by_date[ds])
        written += 1
    print(f"[ics-import] wrote {written} daily files", file=sys.stderr)
    return 0


if __name__ == "__main__":
    sys.exit(main())
