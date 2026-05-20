#!/usr/bin/env python3
"""brain-calendar-attendee-stats — build attendee frequency table from
~/brain/daily/calendar/*/*.md.

No LLM, no API cost. Pure file walk + regex. Output:
    {name: {"count": N, "first": date, "last": date, "events": [(date, title), ...]}}

Used to scope agent-side enrichment (recipe Step 6) before dispatching
subagents. Notable threshold = 3+ occurrences.
"""
from __future__ import annotations
import json
import re
import sys
from collections import defaultdict
from pathlib import Path

CAL_ROOT = Path.home() / "brain/daily/calendar"
NOTABLE_THRESHOLD = 3

# Lines look like:
#   - **HH:MM-HH:MM** **Title** 📍 Location — with Name1, Name2, ...
# or — with email@host, Full Name, ...
LINE_RE = re.compile(
    r"^- \*\*[\w\-:]+\*\* \*\*(?P<title>[^*]+)\*\*"
    r".*?(?:— with (?P<attendees>.+))?$"
)


def parse_file(path: Path) -> list[tuple[str, list[str]]]:
    """Return list of (event_title, attendee_names_list) for one daily file."""
    out = []
    in_cal = False
    for line in path.read_text().splitlines():
        if line.startswith("## Calendar"):
            in_cal = True
            continue
        if line.startswith("## ") and in_cal:
            in_cal = False
            continue
        if not in_cal or not line.startswith("- "):
            continue
        m = LINE_RE.match(line)
        if not m:
            continue
        title = m.group("title").strip()
        attendees_raw = m.group("attendees") or ""
        # Split on commas; handle "Last, First" by NOT splitting inside angle brackets etc.
        # Simpler: split on commas, trim. Names with commas in them are rare here.
        attendees = [a.strip() for a in attendees_raw.split(",") if a.strip()]
        out.append((title, attendees))
    return out


def main():
    if not CAL_ROOT.exists():
        print(f"no {CAL_ROOT}", file=sys.stderr)
        return 1

    files = sorted(CAL_ROOT.glob("*/2*-*.md"))
    print(f"[attendee-stats] scanning {len(files)} daily files…", file=sys.stderr)

    # name → {"events": [(date, title)], "emails": set, "first": str, "last": str}
    stats: dict[str, dict] = defaultdict(
        lambda: {"events": [], "emails": set(), "first": "9999", "last": "0000"}
    )

    total_events = 0
    for f in files:
        date_str = f.stem  # YYYY-MM-DD
        for title, attendees in parse_file(f):
            total_events += 1
            for a in attendees:
                # Key: lowercase for dedup. Keep email separately if it looks like one.
                key = a.lower().strip()
                if "@" in key:
                    # email form
                    stats[key]["emails"].add(key)
                else:
                    # name form
                    pass
                stats[key]["events"].append((date_str, title))
                if date_str < stats[key]["first"]:
                    stats[key]["first"] = date_str
                if date_str > stats[key]["last"]:
                    stats[key]["last"] = date_str

    # Sort by event count desc
    sorted_attendees = sorted(stats.items(), key=lambda kv: -len(kv[1]["events"]))

    notable = [(k, v) for k, v in sorted_attendees
               if len(v["events"]) >= NOTABLE_THRESHOLD]

    print(f"[attendee-stats] {total_events} attendee-mentions across {len(files)} files",
          file=sys.stderr)
    print(f"[attendee-stats] {len(stats)} unique attendee keys", file=sys.stderr)
    print(f"[attendee-stats] {len(notable)} notable (≥{NOTABLE_THRESHOLD} meetings)",
          file=sys.stderr)
    print(file=sys.stderr)

    # Print top 50 to stdout as a table
    print(f"{'COUNT':>5}  {'FIRST':<10}  {'LAST':<10}  ATTENDEE")
    print("-" * 80)
    for k, v in notable[:50]:
        print(f"{len(v['events']):>5}  {v['first']:<10}  {v['last']:<10}  {k}")

    # Dump full notable JSON for later subagent use
    out_path = CAL_ROOT / ".attendee-stats.json"
    out_data = {
        "generated_at": str(sorted(files)[-1].stem),
        "total_files_scanned": len(files),
        "total_attendee_mentions": total_events,
        "unique_attendees": len(stats),
        "notable_threshold": NOTABLE_THRESHOLD,
        "notable_count": len(notable),
        "notable": [
            {
                "key": k,
                "count": len(v["events"]),
                "first": v["first"],
                "last": v["last"],
                "emails": sorted(v["emails"]),
                "events": v["events"],
            }
            for k, v in notable
        ],
    }
    out_path.write_text(json.dumps(out_data, indent=2, default=str))
    print(f"\n[attendee-stats] wrote {out_path}", file=sys.stderr)

    return 0


if __name__ == "__main__":
    sys.exit(main())
