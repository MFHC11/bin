#!/usr/bin/env python3
"""brain-calendar-attendee-canonicalize — collapse the noisy attendee-stats.json
into a canonical {slug → person_record} map by matching against existing
~/brain/people/*.md frontmatter (email + slug) and a normalized-name index.

No LLM. Read once, write once. Used to feed Sonnet enrichment subagents a
clean list so two subagents never race on the same page.
"""
from __future__ import annotations
import json
import re
import sys
from collections import defaultdict
from pathlib import Path

BRAIN = Path.home() / "brain"
PEOPLE = BRAIN / "people"
STATS = BRAIN / "daily/calendar/.attendee-stats.json"
OUT = BRAIN / "daily/calendar/.attendee-canonical.json"

NAME_NORMALIZE_RE = re.compile(r"[^a-z0-9]+")
EMAIL_RE = re.compile(r"^[\w.+-]+@[\w.-]+\.[a-z]{2,}$", re.IGNORECASE)
SOURCE_QUOTE_RE = re.compile(r"^['\"`](.+)['\"`]$")

# Single-token names that are too ambiguous to route to a canonical slug.
AMBIGUOUS_SINGLE_NAMES = {
    "dan", "brett", "howard", "chris", "ami", "tom", "mark", "mike", "john",
    "alex", "ben", "sam", "dave", "david", "james", "kim", "elizabeth",
    "shanbor",  # is real but we have no surname signal
}


def normalize(s: str) -> str:
    s = s.lower().strip()
    m = SOURCE_QUOTE_RE.match(s)
    if m:
        s = m.group(1)
    return NAME_NORMALIZE_RE.sub("-", s).strip("-")


def load_people_index() -> tuple[dict[str, str], dict[str, str]]:
    """Build (email → slug) and (normalized-title → slug) lookups from people/*.md."""
    email_to_slug: dict[str, str] = {}
    name_to_slug: dict[str, str] = {}
    for f in PEOPLE.glob("*.md"):
        slug = f.stem
        try:
            head = f.read_text()[:2000]
        except OSError:
            continue
        # Frontmatter email lines
        for m in re.finditer(r"^email:\s*(\S+)", head, re.MULTILINE):
            email_to_slug[m.group(1).lower().strip()] = slug
        # Title from frontmatter
        m = re.search(r"^title:\s*(.+)$", head, re.MULTILINE)
        if m:
            name_to_slug[normalize(m.group(1))] = slug
        # And the slug itself is implicitly normalized-name
        name_to_slug.setdefault(slug, slug)
        # Aliases line: aliases: [foo, bar]
        m = re.search(r"^aliases?:\s*\[([^\]]+)\]", head, re.MULTILINE)
        if m:
            for a in m.group(1).split(","):
                a = a.strip().strip("'\"")
                if a:
                    name_to_slug[normalize(a)] = slug
    return email_to_slug, name_to_slug


def attempt_match(key: str, email_idx: dict[str, str],
                  name_idx: dict[str, str]) -> tuple[str | None, str]:
    """Return (matched_slug | None, match_reason)."""
    key = key.strip()
    m = SOURCE_QUOTE_RE.match(key)
    if m:
        key = m.group(1).strip()
    if EMAIL_RE.match(key):
        # Direct email lookup
        if key.lower() in email_idx:
            return email_idx[key.lower()], "email-match"
        # Try prefix as name candidate
        local = key.split("@", 1)[0]
        cand = normalize(local.replace(".", " "))
        if cand in name_idx:
            return name_idx[cand], "email-prefix-as-name"
        return None, "no-match-email"
    # Name form
    norm = normalize(key)
    if norm in name_idx:
        return name_idx[norm], "name-match"
    # Single-token: too ambiguous
    if " " not in key and "-" not in norm:
        if norm in AMBIGUOUS_SINGLE_NAMES:
            return None, "ambiguous-single"
    return None, "no-match-name"


def main():
    if not STATS.exists():
        print(f"missing {STATS} — run brain-calendar-attendee-stats.py first",
              file=sys.stderr)
        return 1
    if not PEOPLE.exists():
        print(f"missing {PEOPLE}", file=sys.stderr)
        return 1

    print(f"[canonicalize] loading people/ index…", file=sys.stderr)
    email_idx, name_idx = load_people_index()
    print(f"[canonicalize] {len(email_idx)} emails, {len(name_idx)} name-slugs indexed",
          file=sys.stderr)

    stats = json.loads(STATS.read_text())
    notable = stats["notable"]
    print(f"[canonicalize] resolving {len(notable)} notable attendee keys…",
          file=sys.stderr)

    # canonical_slug → person record
    by_slug: dict[str, dict] = defaultdict(lambda: {
        "aliases": [],
        "emails": set(),
        "events": [],
        "match_reasons": set(),
    })
    unresolved: list[dict] = []
    ambiguous: list[dict] = []

    for entry in notable:
        key = entry["key"]
        slug, reason = attempt_match(key, email_idx, name_idx)
        if slug:
            rec = by_slug[slug]
            rec["aliases"].append(key)
            if EMAIL_RE.match(key):
                rec["emails"].add(key.lower())
            rec["emails"].update(entry.get("emails", []))
            rec["events"].extend(entry["events"])
            rec["match_reasons"].add(reason)
        else:
            payload = {
                "key": key,
                "count": entry["count"],
                "first": entry["first"],
                "last": entry["last"],
                "emails": entry.get("emails", []),
                "reason": reason,
            }
            if reason == "ambiguous-single":
                ambiguous.append(payload)
            else:
                unresolved.append(payload)

    # Finalize: compute aggregate stats per canonical
    canonical: list[dict] = []
    for slug, rec in by_slug.items():
        events = rec["events"]
        dates = sorted({e[0] for e in events})
        canonical.append({
            "slug": slug,
            "page_path": f"people/{slug}.md",
            "exists": (PEOPLE / f"{slug}.md").exists(),
            "aliases": sorted(set(rec["aliases"])),
            "emails": sorted(rec["emails"]),
            "match_reasons": sorted(rec["match_reasons"]),
            "meeting_count": len(events),
            "unique_dates": len(dates),
            "first": dates[0] if dates else None,
            "last": dates[-1] if dates else None,
            "sample_event_titles": list(dict.fromkeys(
                [t for _, t in events[:20]]
            ))[:10],
        })
    canonical.sort(key=lambda r: -r["meeting_count"])

    out = {
        "generated_from": str(STATS),
        "people_pages_indexed": len(set(email_idx.values()) | set(name_idx.values())),
        "canonical_count": len(canonical),
        "unresolved_count": len(unresolved),
        "ambiguous_count": len(ambiguous),
        "canonical": canonical,
        "unresolved": sorted(unresolved, key=lambda r: -r["count"]),
        "ambiguous": sorted(ambiguous, key=lambda r: -r["count"]),
    }
    OUT.write_text(json.dumps(out, indent=2, default=str))

    print(f"[canonicalize] {len(canonical)} canonical people"
          f" ({sum(1 for c in canonical if c['exists'])} existing pages,"
          f" {sum(1 for c in canonical if not c['exists'])} would-be stubs)",
          file=sys.stderr)
    print(f"[canonicalize] {len(unresolved)} unresolved (need stub or skip)",
          file=sys.stderr)
    print(f"[canonicalize] {len(ambiguous)} ambiguous single-name keys (deferred)",
          file=sys.stderr)
    print(f"[canonicalize] wrote {OUT}", file=sys.stderr)

    # Print top-30 canonical for visual check
    print()
    print(f"{'COUNT':>5}  {'EXISTS':<6}  {'SLUG':<35}  ALIASES")
    print("-" * 100)
    for r in canonical[:30]:
        ex = "✓" if r["exists"] else "·"
        aliases = ", ".join(r["aliases"][:3])
        if len(r["aliases"]) > 3:
            aliases += f" (+{len(r['aliases']) - 3} more)"
        print(f"{r['meeting_count']:>5}  {ex:<6}  {r['slug']:<35}  {aliases}")

    return 0


if __name__ == "__main__":
    sys.exit(main())
