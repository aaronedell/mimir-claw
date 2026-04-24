#!/usr/bin/env python3
"""
chat_sweeper.py — Sweep OpenClaw session transcripts into daily memory files.

Reads all session JSONL files under ~/.openclaw/agents/<agent>/sessions/,
extracts user+assistant exchanges, and appends them to
<workspace>/memory/YYYY-MM-DD-chats.md.

Incremental: uses a cursor file to track the highest timestamp seen per session,
so subsequent runs only process new messages.

Configuration (environment variables):
  MIMIR_WORKSPACE   Path to workspace root (default: ~/.openclaw/workspace)
  MIMIR_AGENTS_DIR  Path to OpenClaw agents dir (default: ~/.openclaw/agents)
  MIMIR_AGENTS      Comma-separated agent allowlist (default: "main")
  MIMIR_TZ          Local time zone (default: system local; falls back to UTC)
  MIMIR_USER_LABEL  Display label for user messages (default: "👤 User")
  MIMIR_AGENT_LABEL Display label for assistant messages (default: "🤖 Agent")
  MIMIR_MAX_CHARS   Truncate message bodies over this length (default: 4000)

Run via cron/LaunchAgent on any interval (15 min is typical). No args needed.

Project: https://github.com/<owner>/mimir-claw
License: MIT
"""
from __future__ import annotations
import json
import os
import re
import sys
from datetime import datetime, timezone
from pathlib import Path

try:
    from zoneinfo import ZoneInfo  # py3.9+
except ImportError:  # pragma: no cover
    ZoneInfo = None  # type: ignore

HOME = Path.home()


def _env_path(name: str, default: Path) -> Path:
    v = os.environ.get(name)
    return Path(os.path.expanduser(v)) if v else default


WORKSPACE = _env_path("MIMIR_WORKSPACE", HOME / ".openclaw" / "workspace")
AGENTS_DIR = _env_path("MIMIR_AGENTS_DIR", HOME / ".openclaw" / "agents")
MEMORY_DIR = WORKSPACE / "memory"
CURSOR_FILE = MEMORY_DIR / ".chat_sweeper_cursor.json"

_tz_name = os.environ.get("MIMIR_TZ")
if _tz_name and ZoneInfo is not None:
    try:
        LOCAL_TZ = ZoneInfo(_tz_name)
    except Exception:
        LOCAL_TZ = None
else:
    LOCAL_TZ = None  # use system local time


AGENT_ALLOWLIST = {
    a.strip() for a in os.environ.get("MIMIR_AGENTS", "main").split(",") if a.strip()
}

USER_LABEL = os.environ.get("MIMIR_USER_LABEL", "👤 User")
AGENT_LABEL = os.environ.get("MIMIR_AGENT_LABEL", "🤖 Agent")
MAX_CHARS = int(os.environ.get("MIMIR_MAX_CHARS", "4000"))


# Message filters — skip obvious heartbeat / boilerplate noise
HEARTBEAT_MARKERS = (
    "Read HEARTBEAT.md if it exists",
    "reply HEARTBEAT_OK",
)
SKIP_EXACT = {"HEARTBEAT_OK", "NO_REPLY", "ok", "k", "ping", "pong"}


# Drop user-message metadata boilerplate that OpenClaw injects
META_BLOCK_RE = re.compile(
    r"(?:Conversation info|Sender|Inbound Context|Group Chat Context|Runtime|Workspace Files)[^\n]*\n```json\n.*?\n```\n?",
    re.DOTALL,
)


def load_cursor() -> dict:
    if CURSOR_FILE.exists():
        try:
            return json.loads(CURSOR_FILE.read_text())
        except Exception:
            return {}
    return {}


def save_cursor(cursor: dict) -> None:
    CURSOR_FILE.parent.mkdir(parents=True, exist_ok=True)
    tmp = CURSOR_FILE.with_suffix(".tmp")
    tmp.write_text(json.dumps(cursor, indent=2))
    tmp.replace(CURSOR_FILE)


def extract_text(content) -> str:
    """Pull plain text out of a message content (string or list of parts)."""
    if isinstance(content, str):
        return content
    if not isinstance(content, list):
        return ""
    chunks = []
    for part in content:
        if not isinstance(part, dict):
            continue
        t = part.get("type")
        if t == "text":
            chunks.append(part.get("text", ""))
        elif t == "tool_use":
            name = part.get("name", "tool")
            chunks.append(f"[tool:{name}]")
        elif t == "tool_result":
            # usually skip; too noisy
            pass
    return "\n".join(c for c in chunks if c).strip()


def clean_user_text(text: str) -> str:
    """Strip the injected metadata prefix from user messages."""
    if not text:
        return text
    cleaned = META_BLOCK_RE.sub("", text)
    return cleaned.strip()


def normalize_ts(raw) -> str | None:
    """Return ISO-8601 UTC string for either ISO input or epoch-ms int."""
    if raw is None:
        return None
    if isinstance(raw, (int, float)):
        try:
            return (
                datetime.fromtimestamp(raw / 1000.0, tz=timezone.utc)
                .isoformat()
                .replace("+00:00", "Z")
            )
        except Exception:
            return None
    if isinstance(raw, str):
        return raw
    return None


def is_noise(role: str, text: str) -> bool:
    t = text.strip()
    if not t:
        return True
    if t in SKIP_EXACT:
        return True
    for marker in HEARTBEAT_MARKERS:
        if marker in t:
            return True
    return False


def parse_session(path: Path, cursor_iso: str | None) -> list[dict]:
    """Return new messages from a session file after cursor_iso (ISO string)."""
    out = []
    try:
        with path.open() as f:
            for line in f:
                line = line.strip()
                if not line:
                    continue
                try:
                    d = json.loads(line)
                except Exception:
                    continue
                if d.get("type") != "message":
                    continue
                msg = d.get("message")
                if not isinstance(msg, dict):
                    continue
                role = msg.get("role")
                if role not in ("user", "assistant"):
                    continue
                ts = normalize_ts(d.get("timestamp")) or normalize_ts(
                    msg.get("timestamp")
                )
                if not ts:
                    continue
                if cursor_iso and ts <= cursor_iso:
                    continue
                text = extract_text(msg.get("content"))
                if role == "user":
                    text = clean_user_text(text)
                if is_noise(role, text):
                    continue
                out.append(
                    {
                        "timestamp": ts,
                        "role": role,
                        "text": text,
                    }
                )
    except FileNotFoundError:
        pass
    return out


def iso_to_local(ts_iso: str) -> datetime:
    try:
        dt = datetime.fromisoformat(ts_iso.replace("Z", "+00:00"))
        if dt.tzinfo is None:
            dt = dt.replace(tzinfo=timezone.utc)
        if LOCAL_TZ is not None:
            return dt.astimezone(LOCAL_TZ)
        return dt.astimezone()  # system local
    except Exception:
        if LOCAL_TZ is not None:
            return datetime.now(LOCAL_TZ)
        return datetime.now().astimezone()


def format_block(msg: dict, agent: str, session_short: str) -> str:
    local_dt = iso_to_local(msg["timestamp"])
    time_str = local_dt.strftime("%H:%M:%S")
    role = msg["role"]
    marker = USER_LABEL if role == "user" else AGENT_LABEL
    header = f"### {time_str} — {marker}  `[{agent}/{session_short}]`"
    body = msg["text"].strip()
    if MAX_CHARS > 0 and len(body) > MAX_CHARS:
        body = body[:MAX_CHARS] + "\n\n... [truncated]"
    return f"{header}\n\n{body}\n"


def date_key(msg: dict) -> str:
    return iso_to_local(msg["timestamp"]).strftime("%Y-%m-%d")


def append_to_daily(date_str: str, blocks: list[str]) -> Path:
    path = MEMORY_DIR / f"{date_str}-chats.md"
    exists = path.exists()
    with path.open("a") as f:
        if not exists:
            f.write(f"# Chat Log — {date_str}\n\n")
            f.write("_Auto-swept by Mimir Claw. Raw conversation record._\n\n")
        for b in blocks:
            f.write(b)
            f.write("\n")
    try:
        os.chmod(path, 0o600)
    except OSError:
        pass
    return path


def main() -> int:
    MEMORY_DIR.mkdir(parents=True, exist_ok=True)
    cursor = load_cursor()
    total_new = 0
    touched_files: set[Path] = set()

    if not AGENTS_DIR.exists():
        print(f"Agents dir not found: {AGENTS_DIR}", file=sys.stderr)
        return 1

    for agent_dir in sorted(AGENTS_DIR.glob("*")):
        if not agent_dir.is_dir():
            continue
        agent = agent_dir.name
        if AGENT_ALLOWLIST and agent not in AGENT_ALLOWLIST:
            continue
        sess_dir = agent_dir / "sessions"
        if not sess_dir.exists():
            continue
        for sess_file in sorted(sess_dir.glob("*.jsonl")):
            name = sess_file.name
            if "checkpoint" in name or name.endswith(".lock"):
                continue
            key = f"{agent}:{sess_file.name}"
            last_ts = cursor.get(key)
            new_msgs = parse_session(sess_file, last_ts)
            if not new_msgs:
                continue
            by_date: dict[str, list[str]] = {}
            session_short = sess_file.stem[:8]
            for m in new_msgs:
                d = date_key(m)
                by_date.setdefault(d, []).append(format_block(m, agent, session_short))
            for d, blocks in by_date.items():
                fp = append_to_daily(d, blocks)
                touched_files.add(fp)
            cursor[key] = new_msgs[-1]["timestamp"]
            total_new += len(new_msgs)

    save_cursor(cursor)

    if total_new:
        print(f"Swept {total_new} messages into {len(touched_files)} file(s):")
        for f in sorted(touched_files):
            print(f"  {f}")
    else:
        print("No new messages.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
