#!/usr/bin/env python3
"""granola-public-import — fetch full Granola notes via the public API.

Uses GRANOLA_API_TOKEN (grn_*, from ~/.gbrain/secrets.env) against
https://public-api.granola.ai. This is the durable token path: it does not
depend on the desktop app's WorkOS token staying fresh.

Usage:
  granola-public-import.py --note-id not_XXXX            # print one note as markdown
  granola-public-import.py --refresh-file <path.md>      # re-export a meetings/granola file in place
  granola-public-import.py --since YYYY-MM-DD            # list notes since date

Created 2026-06-11 (Great Compilation follow-up; token rotation).
"""
import os, sys, json, ssl, gzip, re, urllib.request, urllib.parse
try:
    import certifi
    CTX = ssl.create_default_context(cafile=certifi.where())
except ImportError:
    CTX = None

BASE = "https://public-api.granola.ai"
TOK = os.environ.get("GRANOLA_API_TOKEN")
if not TOK:
    sys.exit("GRANOLA_API_TOKEN not set; source ~/.gbrain/secrets.env")

def get(path):
    req = urllib.request.Request(BASE + path, headers={
        "Authorization": f"Bearer {TOK}", "Accept-Encoding": "gzip"})
    with urllib.request.urlopen(req, timeout=90, context=CTX) as r:
        raw = r.read()
        if r.headers.get("Content-Encoding") == "gzip":
            raw = gzip.decompress(raw)
        return json.loads(raw)

def note_markdown(note_id):
    d = get(f"/v1/notes/{urllib.parse.quote(note_id)}?include=transcript")
    title = d.get("title") or "Untitled"
    created = (d.get("created_at") or "")[:10]
    att = ", ".join((a.get("name") or a.get("email") or "?") for a in (d.get("attendees") or []))
    lines = [f"# {title}", "", f"**Date:** {created}", f"**Attendees:** {att}",
             f"**Granola:** {d.get('web_url','')}", ""]
    summ = d.get("summary_markdown") or d.get("summary_text") or ""
    if summ:
        lines += ["## Summary", "", summ, ""]
    tr = d.get("transcript") or []
    if tr:
        lines += ["## Transcript", ""]
        cur_src, buf = None, []
        for u in tr:
            src = (u.get("speaker") or {}).get("source") or "?"
            txt = (u.get("text") or "").strip()
            if not txt: continue
            if src != cur_src and buf:
                lines.append(f"**[{cur_src}]** " + " ".join(buf)); buf = []
            cur_src = src; buf.append(txt)
        if buf: lines.append(f"**[{cur_src}]** " + " ".join(buf))
    return "\n".join(lines), len(tr)

def refresh_file(path):
    t = open(path).read()
    m = re.search(r"^granola_id:\s*(\S+)", t, re.M)
    if not m: sys.exit(f"no granola_id in {path}")
    nid = m.group(1)
    fm = re.match(r"^---\n.*?\n---\n", t, re.S)
    front = fm.group(0) if fm else ""
    body, n = note_markdown(nid)
    open(path, "w").write(front + "\n" + body + "\n")
    print(f"refreshed {path}: {n} utterances")

if __name__ == "__main__":
    a = sys.argv[1:]
    if a[:1] == ["--note-id"]:
        body, n = note_markdown(a[1]); print(body)
    elif a[:1] == ["--refresh-file"]:
        refresh_file(a[1])
    elif a[:1] == ["--since"]:
        d = get(f"/v1/notes?created_after={a[1]}&page_size=30")
        for nt in d.get("notes", []):
            print(nt.get("id"), (nt.get("created_at") or "")[:16], nt.get("title"))
    else:
        sys.exit(__doc__)
