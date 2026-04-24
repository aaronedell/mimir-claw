# Mimir Claw 🧠

**Persistent memory sweeper for [OpenClaw](https://openclaw.ai).**

If your agent keeps forgetting what you talked about yesterday — this fixes that.

Mimir Claw reads your OpenClaw session transcripts and appends clean, daily Markdown logs to your workspace's `memory/` directory. Your agent can then read those files on startup and actually remember prior conversations.

Named for [Mímir](https://en.wikipedia.org/wiki/M%C3%ADmir) — the Norse god renowned for his knowledge and wisdom.

---

## The problem

OpenClaw agents wake up fresh each session. Unless you write things down, they forget. Built-in `MEMORY.md` curation is great for long-term wisdom, but there's no raw, searchable record of *what was actually said* across sessions and channels.

## The fix

A ~250-line Python script + a launchd/cron job that, every 15 minutes:

1. Scans `~/.openclaw/agents/<agent>/sessions/*.jsonl`
2. Extracts new user + assistant messages since last run (cursor-based, incremental)
3. Strips OpenClaw's injected metadata blocks and heartbeat noise
4. Appends clean Markdown blocks to `<workspace>/memory/YYYY-MM-DD-chats.md`

Your agent can then read today + yesterday's `*-chats.md` on session start and have continuous context.

## Example output

```markdown
# Chat Log — 2026-04-24

_Auto-swept by Mimir Claw. Raw conversation record._

### 07:00:12 — 👤 User  `[main/01KPXY2A]`

Can we talk about that thing we built last week?

### 07:00:34 — 🤖 Agent  `[main/01KPXY2A]`

Yeah — you mean the memory sweeper? Here's where we left off…
```

---

## Install

Requires **Python 3.9+** (stdlib only, no dependencies) and an OpenClaw install.

```bash
git clone https://github.com/<owner>/mimir-claw.git
cd mimir-claw
./install.sh
```

The installer will:
- Copy `chat_sweeper.py` to `~/.local/share/mimir-claw/`
- On **macOS**: install a LaunchAgent that runs every 15 minutes
- On **Linux**: print a ready-to-paste crontab line
- Run once immediately to verify

### Uninstall

```bash
./install.sh --uninstall
```

---

## Configuration

All config via environment variables — set them in the LaunchAgent plist or your crontab:

| Variable | Default | What |
|---|---|---|
| `MIMIR_WORKSPACE` | `~/.openclaw/workspace` | Where to write `memory/*.md` |
| `MIMIR_AGENTS_DIR` | `~/.openclaw/agents` | Where OpenClaw sessions live |
| `MIMIR_AGENTS` | `main` | Comma-separated agent allowlist |
| `MIMIR_TZ` | system local | IANA tz name (e.g. `America/Los_Angeles`) |
| `MIMIR_USER_LABEL` | `👤 User` | Label for user messages |
| `MIMIR_AGENT_LABEL` | `🤖 Agent` | Label for assistant messages |
| `MIMIR_MAX_CHARS` | `4000` | Truncate long messages |

## Teach your agent to use it

Add to your agent's `AGENTS.md` (or equivalent bootstrap instructions):

```markdown
At the start of every session, read:
- memory/YYYY-MM-DD-chats.md (today)
- memory/<yesterday>-chats.md

These are raw conversation logs from recent sessions. Use them for continuity.
```

---

## How it works

- **Incremental:** a small JSON cursor file tracks the last timestamp swept per session file, so re-runs are cheap.
- **Filters:** heartbeat polls, empty replies, and `NO_REPLY` / `HEARTBEAT_OK` boilerplate get dropped.
- **Metadata stripping:** OpenClaw's trusted/untrusted metadata JSON blocks are removed from user message bodies.
- **Daily files:** messages are grouped by local date, so long sessions spanning midnight split correctly.
- **chmod 600:** daily log files are written user-read-only.

## FAQ

**Does it re-sweep old messages?**
No — it advances a cursor after each run. Delete `memory/.chat_sweeper_cursor.json` to re-sweep from scratch.

**Can it sweep multiple agents / subagents?**
Yes, set `MIMIR_AGENTS=main,worker,watchdog` (comma-separated). Default is `main` only — subagent logs are usually too noisy to be useful.

**Does it send data anywhere?**
No. It only reads local JSONL files and writes local Markdown files. No network calls.

**Can I use this with non-OpenClaw agents?**
Probably — if their session format is similar JSONL with `{type: "message", message: {role, content, timestamp}}`. PRs welcome.

---

## License

MIT. See [LICENSE](LICENSE).

Built by [@aaronedell](https://github.com/aaronedell) and his OpenClaw agent.
