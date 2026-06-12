"""ClawVisor gateway helper used by brain-{email,calendar,granola}-* scripts.

Reads CLAWVISOR_URL, CLAWVISOR_AGENT_TOKEN, CLAWVISOR_BRAIN_TASK_ID from env
(populated by the master 9 AM script from macOS Keychain). All requests use a
single session_id per process invocation, as required for standing tasks.

Read-only by design — every authorized action on the brain-ingestion standing
task is read-only across Gmail, Calendar, and Granola.
"""
from __future__ import annotations
import json
import os
import sys
import ssl
import uuid
import urllib.request
import urllib.error
from typing import Any

# Python 3.14 framework install doesn't trust the system keychain by default.
# Point urllib at certifi's bundle so HTTPS to ClawVisor works under cron.
try:
    import certifi  # type: ignore
    _SSL_CONTEXT = ssl.create_default_context(cafile=certifi.where())
except ImportError:
    _SSL_CONTEXT = ssl.create_default_context()

CLAWVISOR_URL = os.environ.get("CLAWVISOR_URL", "https://app.clawvisor.com").rstrip("/")
AGENT_TOKEN = os.environ.get("CLAWVISOR_AGENT_TOKEN")
TASK_ID = os.environ.get("CLAWVISOR_BRAIN_TASK_ID")
SESSION_ID = str(uuid.uuid4())  # one per process

WAIT_TIMEOUT_SEC = 120


def _check_creds() -> None:
    missing = []
    if not AGENT_TOKEN:
        missing.append("CLAWVISOR_AGENT_TOKEN")
    if not TASK_ID:
        missing.append("CLAWVISOR_BRAIN_TASK_ID")
    if missing:
        print(f"FATAL: missing env vars: {', '.join(missing)}", file=sys.stderr)
        print("Run the master script ~/bin/brain-daily.sh or `source` keychain reads first.", file=sys.stderr)
        sys.exit(2)


def gateway_request(
    service: str,
    action: str,
    params: dict[str, Any],
    reason: str,
    data_origin: str | None = None,
    timeout_sec: int | None = None,
) -> dict[str, Any]:
    """Make a ClawVisor gateway request. Returns the `result` dict on success.

    Raises RuntimeError on non-`executed` statuses (blocked, restricted, error).
    timeout_sec overrides WAIT_TIMEOUT_SEC for slow actions (big attachments).
    """
    _check_creds()
    wait_sec = timeout_sec or WAIT_TIMEOUT_SEC
    body = {
        "service": service,
        "action": action,
        "params": params,
        "reason": reason,
        "request_id": str(uuid.uuid4()),
        "task_id": TASK_ID,
        "session_id": SESSION_ID,
        "context": {"source": "scheduled_task", "data_origin": data_origin},
    }
    url = f"{CLAWVISOR_URL}/api/gateway/request?wait=true&timeout={wait_sec}"
    req = urllib.request.Request(
        url,
        data=json.dumps(body).encode("utf-8"),
        headers={
            "Authorization": f"Bearer {AGENT_TOKEN}",
            "Content-Type": "application/json",
        },
        method="POST",
    )
    try:
        with urllib.request.urlopen(req, timeout=wait_sec + 10, context=_SSL_CONTEXT) as resp:
            payload = json.loads(resp.read())
    except urllib.error.HTTPError as e:
        try:
            payload = json.loads(e.read())
        except Exception:
            payload = {"status": "error", "error": str(e)}

    status = payload.get("status")
    if status == "executed":
        return payload.get("result", {})
    if status in ("blocked", "restricted"):
        raise RuntimeError(f"ClawVisor {status}: {payload.get('code', '?')} — {payload.get('reason') or payload.get('error') or 'see audit log'}")
    code = payload.get("code") or payload.get("error") or "?"
    raise RuntimeError(f"ClawVisor request failed: status={status} code={code} message={payload.get('message') or payload.get('error') or json.dumps(payload)[:200]}")


def paginate(service: str, action: str, base_params: dict[str, Any], reason: str,
             items_key: str = "items", page_token_param: str = "page_token",
             page_token_field: str = "next_page_token", max_pages: int = 20,
             data_origin: str | None = None) -> list[dict[str, Any]]:
    """Walk a paginated action. Stops when no more pages or max_pages reached."""
    out: list[dict[str, Any]] = []
    params = dict(base_params)
    for _ in range(max_pages):
        result = gateway_request(service, action, params, reason, data_origin=data_origin)
        data = result.get("data", {})
        items = data.get(items_key) or data.get("messages") or data.get("events") or data.get("meetings") or []
        out.extend(items)
        meta = result.get("meta", {})
        next_tok = meta.get(page_token_field) or data.get(page_token_field)
        if not next_tok:
            break
        params[page_token_param] = next_tok
    return out
