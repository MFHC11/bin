#!/usr/bin/env python3
"""brain-email-collect — pull recent Gmail via ClawVisor; emit JSON + digest.

Outputs:
  ~/.gbrain/integrations/email-to-brain/messages/YYYY-MM-DD.json
  ~/.gbrain/integrations/email-to-brain/digests/YYYY-MM-DD.md
  ~/.gbrain/integrations/email-to-brain/state.json
  ~/.gbrain/integrations/email-to-brain/heartbeat.jsonl

Designed to drop new emails into ~/brain/inbox/ in the format the
inbox-enrich skill expects: date-prefixed filename, frontmatter with
type/tags/date/thread_id, plus structured Summary / Contacts /
Mentioned organisations / Source sections.

Reads env from the keychain via the master 9 AM script.
"""
from __future__ import annotations
import base64
import datetime as dt
import email.utils
import json
import os
import re
import sys
from html.parser import HTMLParser
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from _clawvisor import gateway_request  # noqa: E402

# ─── Config ───────────────────────────────────────────────────────────────────

GMAIL_SERVICE = "google.gmail:marcus@erv.io"
DEFAULT_WINDOW = "newer_than:1d"
MAX_MESSAGES = 200  # per-call cap; collector loops if more pages exist

# Body text carried into the inbox note. Raised from 1500/1200 (2026-06-12):
# long emails were being truncated before enrichment ever saw them.
BODY_CHARS = 10_000

# Attachment download policy: only document types worth converting, and only
# below a sanity cap. Inline signature images etc. are listed but never fetched.
# Downloads go straight into ~/brain/inbox/ where brain-pdf-worker drains *.pdf.
DOWNLOAD_MIMES = {"application/pdf"}
MAX_ATTACHMENT_BYTES = 25 * 1024 * 1024

# Set True after the first SCOPE_MISMATCH so one run never spams ClawVisor
# with doomed download requests. get_attachment requires a standing-task
# scope expansion (POST /api/tasks/<task>/expand) approved by Marcus.
_ATTACHMENT_SCOPE_BLOCKED = False


def _resolve_window(argv: list[str]) -> str:
    """Build the Gmail `q:` value from CLI flags (or fall back to DEFAULT_WINDOW).

    Supported flags:
      --start YYYY-MM-DD   inclusive lower bound (Gmail `after:`)
      --end   YYYY-MM-DD   exclusive upper bound (Gmail `before:` is exclusive)
      --query "<raw>"      raw Gmail query string, overrides above
    """
    for i, a in enumerate(argv):
        if a == "--query" and i + 1 < len(argv):
            return argv[i + 1]
    start = end = None
    for i, a in enumerate(argv):
        if a == "--start" and i + 1 < len(argv):
            start = argv[i + 1]
        elif a == "--end" and i + 1 < len(argv):
            end = argv[i + 1]
    if start or end:
        parts = []
        if start:
            parts.append(f"after:{start.replace('-', '/')}")
        if end:
            # Gmail's before: is exclusive; bump end by 1 day so --end is inclusive
            try:
                ed = dt.date.fromisoformat(end) + dt.timedelta(days=1)
                parts.append(f"before:{ed.isoformat().replace('-', '/')}")
            except Exception:
                parts.append(f"before:{end.replace('-', '/')}")
        return " ".join(parts)
    return DEFAULT_WINDOW

# Noise filter: senders to skip entirely (substring match, lowercased)
NOISE_SENDERS = [
    "noreply", "no-reply", "notifications@", "calendar-notification",
    "mailer-daemon", "postmaster", "donotreply",
]
SIGNATURE_PATTERNS = [
    re.compile(p, re.I) for p in [
        r"docusign", r"dropbox sign", r"hellosign", r"pandadoc",
        r"please sign", r"signature needed", r"ready for your signature",
        r"everyone has signed", r"you just signed",
    ]
]

ROLE_ADDRESSES = ("marketing@", "info@", "hello@", "noreply@", "support@",
                  "accounts@", "billing@", "admin@", "team@")
COMMON_PROVIDERS = ("@gmail.com", "@outlook.com", "@icloud.com",
                    "@yahoo.com", "@hotmail.com", "@me.com")

INTEGRATION_DIR = Path.home() / ".gbrain/integrations/email-to-brain"
MSG_DIR = INTEGRATION_DIR / "messages"
DIGEST_DIR = INTEGRATION_DIR / "digests"
STATE_FILE = INTEGRATION_DIR / "state.json"
HEARTBEAT_FILE = INTEGRATION_DIR / "heartbeat.jsonl"

INBOX_DIR = Path.home() / "brain/inbox"

TODAY = dt.datetime.utcnow().strftime("%Y-%m-%d")
NOW_ISO = dt.datetime.utcnow().strftime("%Y-%m-%dT%H:%M:%SZ")


def _ensure_dirs():
    for p in (MSG_DIR, DIGEST_DIR, INBOX_DIR):
        p.mkdir(parents=True, exist_ok=True)


def _load_state() -> dict:
    try:
        return json.loads(STATE_FILE.read_text())
    except Exception:
        return {"known_ids": [], "last_collect": None}


def _save_state(state: dict):
    STATE_FILE.write_text(json.dumps(state, indent=2))


def _heartbeat(status: str, details: dict):
    HEARTBEAT_FILE.parent.mkdir(parents=True, exist_ok=True)
    with HEARTBEAT_FILE.open("a") as f:
        f.write(json.dumps({"ts": NOW_ISO, "event": "collect",
                            "status": status, "details": details}) + "\n")


# ─── Helpers ──────────────────────────────────────────────────────────────────

class _HTMLStripper(HTMLParser):
    def __init__(self):
        super().__init__()
        self.parts = []
    def handle_data(self, data):
        self.parts.append(data)


def strip_html(s: str) -> str:
    p = _HTMLStripper()
    try:
        p.feed(s)
    except Exception:
        return s
    return "".join(p.parts)


def decode_b64(s: str) -> str:
    """Gmail's body data is base64url-encoded."""
    try:
        padding = "=" * (-len(s) % 4)
        return base64.urlsafe_b64decode(s + padding).decode("utf-8", "replace")
    except Exception:
        return ""


def is_noise(from_addr: str) -> bool:
    a = (from_addr or "").lower()
    return any(p in a for p in NOISE_SENDERS)


def is_signature_request(subject: str, from_addr: str) -> bool:
    blob = f"{subject or ''} {from_addr or ''}"
    return any(p.search(blob) for p in SIGNATURE_PATTERNS)


def gmail_link(msg_id: str, account: str = "marcus@erv.io") -> str:
    return f"https://mail.google.com/mail/u/?authuser={account}#inbox/{msg_id}"


def slugify(text: str, max_len: int = 60) -> str:
    s = (text or "untitled").lower()
    s = re.sub(r"[^\w\s-]", "", s)
    s = re.sub(r"[-\s]+", "-", s).strip("-")
    return s[:max_len].strip("-") or "untitled"


def extract_email_addr(s: str) -> str | None:
    if not s:
        return None
    m = re.search(r"<([^>]+)>", s)
    if m:
        return m.group(1)
    m = re.match(r"\s*([^\s,;]+@[^\s,;]+)\s*$", s)
    return m.group(1) if m else None


def extract_display_name(s: str) -> str | None:
    if not s:
        return None
    m = re.match(r'^"?([^"<]+?)"?\s*<', s)
    if m:
        return m.group(1).strip()
    return None


# ─── Collect ──────────────────────────────────────────────────────────────────

def collect():
    _ensure_dirs()
    state = _load_state()
    known = set(state.get("known_ids", []))

    window = _resolve_window(sys.argv[1:])

    # Step 1: list message IDs in window. ClawVisor's google.gmail adapter
    # exposes Gmail's `q:` filter under the `query` parameter (not `q`).
    # `max_results` is capped at 200 per call by the adapter; paginate via
    # `page_token` for larger windows.
    raw_msgs: list[dict] = []
    page_token: str | None = None
    pages_fetched = 0
    max_pages = 10
    while pages_fetched < max_pages:
        params: dict[str, object] = {"query": window, "max_results": MAX_MESSAGES}
        if page_token:
            params["page_token"] = page_token
        listing = gateway_request(
            GMAIL_SERVICE, "list_messages", params,
            reason=f"Brain-ingestion pipeline: enumerate Gmail messages matching "
                   f"the date-bounded query window for filing into the inbox-enrich "
                   f"pipeline at ~/brain/inbox/. This is part of the daily 9 AM cron "
                   f"and backfill workflows.",
        )
        data = listing.get("data", {})
        if isinstance(data, list):
            page_msgs = data
        else:
            page_msgs = data.get("messages") or data.get("items") or []
        raw_msgs.extend(page_msgs)
        meta = listing.get("meta", {}) or {}
        page_token = meta.get("next_page_token")
        pages_fetched += 1
        if not page_token or not page_msgs:
            break

    print(f"[email-collect] window={window!r} → {len(raw_msgs)} candidates "
          f"(pages={pages_fetched})", file=sys.stderr)

    new_records: list[dict] = []
    for entry in raw_msgs:
        msg_id = entry.get("id") or entry.get("message_id")
        if not msg_id or msg_id in known:
            continue

        # Fetch full message
        try:
            msg_result = gateway_request(
                GMAIL_SERVICE, "get_message", {"message_id": msg_id},
                reason="Daily 9 AM brain-ingestion: read full body and headers of one Gmail "
                       "message to extract sender, subject, recipients, mentioned organisations, "
                       "and any action items for filing into ~/brain/inbox/.",
                data_origin=f"gmail:msg-{msg_id}",
            )
        except RuntimeError as e:
            print(f"[email-collect] get_message {msg_id} failed: {e}", file=sys.stderr)
            continue

        msg_data = msg_result.get("data", {})
        rec = build_record(msg_id, msg_data)
        if not rec:
            continue
        new_records.append(rec)
        known.add(msg_id)

    # Save JSON
    out_json = MSG_DIR / f"{TODAY}.json"
    existing = []
    if out_json.exists():
        try:
            existing = json.loads(out_json.read_text())
        except Exception:
            existing = []
    out_json.write_text(json.dumps(existing + new_records, indent=2))

    # Update state
    state["known_ids"] = list(known)[-2000:]  # bounded
    state["last_collect"] = NOW_ISO
    _save_state(state)

    # Write to brain/inbox (inbox-enrich skill consumes these)
    written_to_inbox = 0
    attachments_saved = 0
    for rec in new_records:
        if rec["category"] == "noise":
            continue
        path = inbox_filepath(rec)
        if path.exists():
            continue
        attachments_saved += download_attachments(rec)
        path.write_text(format_inbox_md(rec))
        written_to_inbox += 1

    _heartbeat("ok", {"new_messages": len(new_records),
                      "inbox_files_written": written_to_inbox,
                      "attachments_saved": attachments_saved,
                      "attachment_scope_blocked": _ATTACHMENT_SCOPE_BLOCKED,
                      "window": window})
    print(f"[email-collect] {len(new_records)} new messages; {written_to_inbox} written to inbox/", file=sys.stderr)
    return new_records


def build_record(msg_id: str, data: dict) -> dict | None:
    """Build a record from ClawVisor's google.gmail adapter response.

    ClawVisor pre-flattens the Gmail API response into:
      id, thread_id, from, to, subject, timestamp, body, is_unread,
      message_id_header, labels
    All as direct top-level fields. No headers list, no payload tree.
    """
    from_addr = data.get("from", "")
    to_addr = data.get("to", "")
    cc_addr = data.get("cc", "")  # often empty; ClawVisor may merge into to
    subject = data.get("subject") or "(no subject)"
    thread_id = data.get("thread_id") or ""
    body_text = (data.get("body") or "").strip()
    if "<" in body_text[:200] and ">" in body_text[:200]:
        # crude HTML detection — strip if present
        body_text = strip_html(body_text)

    # Date from `timestamp` — ClawVisor sometimes returns ISO 8601, sometimes
    # RFC 2822 ("Wed, 13 May 2026 09:42:11 +0100"). Handle both. Important:
    # the previous "T in first 11 chars" heuristic was wrong because RFC 2822
    # strings like "Tue, 12 May ..." also start with T. Require an actual ISO
    # date pattern.
    ts = (data.get("timestamp") or "").strip()
    date_str = TODAY
    if ts:
        try:
            if re.match(r"^\d{4}-\d{2}-\d{2}", ts):
                # ISO 8601 — first 10 chars are YYYY-MM-DD
                date_str = ts[:10]
            else:
                parsed = email.utils.parsedate_to_datetime(ts)
                if parsed:
                    date_str = parsed.strftime("%Y-%m-%d")
        except Exception:
            date_str = TODAY

    contacts = extract_contacts(from_addr, to_addr, cc_addr)
    orgs = extract_orgs(contacts, subject + " " + body_text[:1500])

    category = "noise" if is_noise(from_addr) else (
        "signature" if is_signature_request(subject, from_addr) else "triage")

    snippet = body_text[:280].replace("\n", " ").strip()

    # ClawVisor's get_message surfaces a flat attachments list:
    # [{attachment_id, filename, mime_type, size}, ...]
    attachments = []
    for a in (data.get("attachments") or []):
        if not isinstance(a, dict) or not a.get("filename"):
            continue
        attachments.append({
            "attachment_id": a.get("attachment_id") or a.get("id") or "",
            "filename": a["filename"],
            "mime_type": (a.get("mime_type") or "").lower(),
            "size": int(a.get("size") or 0),
            "saved_as": None,  # filled by download_attachments()
        })

    return {
        "id": msg_id,
        "thread_id": thread_id,
        "date": date_str,
        "from": from_addr,
        "to": to_addr,
        "cc": cc_addr,
        "subject": subject,
        "snippet": snippet,
        "body_text_preview": body_text[:BODY_CHARS],
        "gmail_link": gmail_link(msg_id),
        "contacts": contacts,
        "orgs": orgs,
        "category": category,
        "is_unread": bool(data.get("is_unread")),
        "labels": data.get("labels") or [],
        "attachments": attachments,
        "has_attachments": bool(attachments),
    }


def download_attachments(rec: dict) -> int:
    """Fetch downloadable attachments (PDFs) into ~/brain/inbox/ for the
    pdf-to-brain worker. Mutates rec["attachments"][i]["saved_as"].

    Fails soft: if the ClawVisor standing task lacks get_attachment scope
    (SCOPE_MISMATCH / pending_scope_expansion), log once, stop trying for the
    rest of the run, and leave the metadata-only listing in the inbox note.
    Returns the number of files written.
    """
    global _ATTACHMENT_SCOPE_BLOCKED
    saved = 0
    for att in rec.get("attachments", []):
        if _ATTACHMENT_SCOPE_BLOCKED:
            break
        if att["mime_type"] not in DOWNLOAD_MIMES:
            continue
        if not att["attachment_id"] or not (0 < att["size"] <= MAX_ATTACHMENT_BYTES):
            continue
        stem = slugify(Path(att["filename"]).stem, max_len=80)
        dest = INBOX_DIR / f"{rec['date']}-attachment-{stem}.pdf"
        if dest.exists():
            att["saved_as"] = dest.name
            continue
        try:
            res = gateway_request(
                GMAIL_SERVICE, "get_attachment",
                {"message_id": rec["id"], "attachment_id": att["attachment_id"]},
                reason="Daily brain-ingestion: download one PDF email attachment so it "
                       "can be filed into ~/brain/inbox/ and converted to a brain page "
                       "by the pdf-to-brain pipeline (read-only knowledge ingestion).",
                data_origin=f"gmail:msg-{rec['id']}",
            )
        except RuntimeError as e:
            msg = str(e)
            if "SCOPE_MISMATCH" in msg or "pending_scope_expansion" in msg or "restricted" in msg.lower():
                _ATTACHMENT_SCOPE_BLOCKED = True
                print("[email-collect] attachment download blocked by ClawVisor task "
                      "scope — listing metadata only. Approve a get_attachment scope "
                      "expansion for the brain-ingestion standing task to enable "
                      "downloads.", file=sys.stderr)
            else:
                print(f"[email-collect] get_attachment failed for "
                      f"{att['filename']!r}: {msg[:200]}", file=sys.stderr)
            continue
        d = res.get("data", {}) if isinstance(res, dict) else {}
        blob = d.get("data") or d.get("content") or d.get("body") or ""
        if not isinstance(blob, str) or not blob:
            print(f"[email-collect] get_attachment returned no payload for "
                  f"{att['filename']!r} (keys: {sorted(d) if isinstance(d, dict) else '?'})",
                  file=sys.stderr)
            continue
        try:
            raw = base64.urlsafe_b64decode(blob + "=" * (-len(blob) % 4))
        except Exception as e:
            print(f"[email-collect] b64 decode failed for {att['filename']!r}: {e}",
                  file=sys.stderr)
            continue
        if not raw.startswith(b"%PDF"):
            print(f"[email-collect] skipped {att['filename']!r}: payload is not a PDF "
                  f"(header {raw[:8]!r})", file=sys.stderr)
            continue
        dest.write_bytes(raw)
        att["saved_as"] = dest.name
        saved += 1
        print(f"[email-collect] saved attachment → inbox/{dest.name} "
              f"({len(raw)} bytes)", file=sys.stderr)
    return saved


def extract_contacts(from_, to_, cc_) -> list[dict]:
    out: list[dict] = []
    seen: set[str] = set()
    for label, raw in [("from", from_), ("to", to_), ("cc", cc_)]:
        for part in re.split(r",\s*", raw or ""):
            part = part.strip()
            if not part:
                continue
            email = extract_email_addr(part)
            if not email:
                continue
            if any(email.lower().startswith(r) for r in ROLE_ADDRESSES):
                continue
            if email in seen:
                continue
            seen.add(email)
            name = extract_display_name(part) or email.split("@")[0]
            out.append({"name": name, "email": email, "header": label})
    return out


def extract_orgs(contacts: list[dict], body_blob: str) -> list[str]:
    """Best-effort: pull org names from contact domains (excluding common providers)
    and from explicit "Mentioned organisations" prose if present."""
    orgs: list[str] = []
    seen: set[str] = set()
    for c in contacts:
        dom = c["email"].split("@")[-1].lower()
        if dom.endswith(COMMON_PROVIDERS):
            continue
        # Heuristic: strip TLD, capitalise
        base = dom.split(".")[0]
        if base not in seen and len(base) > 2:
            seen.add(base)
            orgs.append(base.replace("-", " ").title())
    # Look for an explicit Mentioned organisations section in forwarded threads
    m = re.search(r"(?:Mentioned organisations|Mentioned Orgs?)[:\s]*\n((?:- .+\n?)+)",
                  body_blob, re.I)
    if m:
        for line in m.group(1).splitlines():
            name = line.lstrip("- ").strip()
            if name and name.lower() not in {o.lower() for o in orgs}:
                orgs.append(name)
    return orgs[:20]


# ─── Inbox formatting (inbox-enrich-compatible) ───────────────────────────────

def inbox_filepath(rec: dict) -> Path:
    slug = slugify(rec["subject"])
    return INBOX_DIR / f"{rec['date']}-email-{slug}.md"


def format_inbox_md(rec: dict) -> str:
    tag_set = ["email"]
    if rec["category"] == "signature":
        tag_set.append("signature")
    if rec["category"] == "noise":
        tag_set.append("noise")

    contacts_md = "\n".join(
        f"- {c['name']} ({c['email']})" for c in rec["contacts"]
    ) or "(none extracted)"

    orgs_md = "\n".join(f"- {o}" for o in rec["orgs"]) or "(none extracted)"

    body_preview = rec.get("body_text_preview") or rec.get("snippet") or ""

    attachments = rec.get("attachments") or []
    att_lines = []
    for a in attachments:
        size_kb = a["size"] // 1024
        if a.get("saved_as"):
            att_lines.append(f"- {a['filename']} ({a['mime_type']}, {size_kb} KB) — saved to [[inbox/{a['saved_as']}]] for pdf-to-brain")
        else:
            att_lines.append(f"- {a['filename']} ({a['mime_type']}, {size_kb} KB) — not downloaded; fetch from Gmail if needed")
    attachments_md = ""
    if att_lines:
        attachments_md = "\n### Attachments\n\n" + "\n".join(att_lines) + "\n"

    return f"""---
type: inbox
tags: {json.dumps(tag_set)}
date: {rec['date']}
thread_id: {rec['thread_id']}
has_attachments: {str(rec.get('has_attachments', False)).lower()}
---

# {rec['subject']}

**From:** {rec['from']}
**To:** {rec['to']}
**Date:** {rec['date']}
**Thread:** {rec['thread_id']}
[Open in Gmail]({rec['gmail_link']})

### Summary

{body_preview[:BODY_CHARS].strip()}
{attachments_md}
### Contacts

{contacts_md}

### Mentioned organisations

{orgs_md}

### Source

- Gmail message id: {rec['id']}
- Gmail thread id: {rec['thread_id']}
- Collected: {NOW_ISO}
"""


# ─── Digest (agent-readable summary) ──────────────────────────────────────────

def digest():
    """Build today's markdown digest from messages/{TODAY}.json."""
    _ensure_dirs()
    json_file = MSG_DIR / f"{TODAY}.json"
    if not json_file.exists():
        return
    records = json.loads(json_file.read_text())
    digest_path = DIGEST_DIR / f"{TODAY}.md"
    lines = [f"# Email Digest — {TODAY}\n",
             f"Total messages collected today: {len(records)}\n"]
    cats = {"signature": [], "triage": [], "noise": []}
    for r in records:
        cats[r["category"]].append(r)
    if cats["signature"]:
        lines.append("\n## ⚠️ Signatures pending\n")
        for r in cats["signature"]:
            lines.append(f"- [{r['subject']}]({r['gmail_link']}) — {r['from']}")
    if cats["triage"]:
        lines.append("\n## Inbox\n")
        for r in cats["triage"]:
            lines.append(f"- [{r['subject']}]({r['gmail_link']}) — {r['from']}")
    if cats["noise"]:
        lines.append(f"\n## Noise ({len(cats['noise'])} filtered)\n")
    digest_path.write_text("\n".join(lines) + "\n")
    print(f"[email-collect] wrote digest: {digest_path}", file=sys.stderr)


# ─── Entry point ──────────────────────────────────────────────────────────────

def main():
    mode = sys.argv[1] if len(sys.argv) > 1 else "collect+digest"
    if mode in ("collect", "collect+digest"):
        try:
            collect()
        except RuntimeError as e:
            print(f"[email-collect] FATAL: {e}", file=sys.stderr)
            _heartbeat("error", {"error": str(e)})
            sys.exit(1)
    if mode in ("digest", "collect+digest"):
        digest()


if __name__ == "__main__":
    main()
