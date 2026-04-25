# Mimir Claw 🧠 — Windows Version

**Persistent memory sweeper for [OpenClaw](https://openclaw.ai).**

This is the Windows-compatible fork of Mimir Claw.

## Install (Windows)

Requires **Python 3.9+** and an OpenClaw install.

### Option 1: Quick Install
```powershell
# Clone and install
git clone https://github.com/aaronedell/mimir-claw.git
cd mimir-claw
.\install.ps1
```

### Option 2: Manual Setup
```powershell
# 1. Copy the Python script to a permanent location
mkdir "$env:USERPROFILE\.local\share\mimir-claw" -Force
copy "chat_sweeper.py" "$env:USERPROFILE\.local\share\mimir-claw\"

# 2. Create the memory directory
mkdir "$env:USERPROFILE\.openclaw\workspace\memory" -Force

# 3. Test it
python "$env:USERPROFILE\.local\share\mimir-claw\chat_sweeper.py"

# 4. Set up Task Scheduler (see below)
```

### Set up Scheduled Task
Run this in PowerShell as Administrator:
```powershell
# Create the scheduled task to run every 15 minutes
$action = New-ScheduledTaskAction -Execute "python" -Argument "$env:USERPROFILE\.local\share\mimir-claw\chat_sweeper.py"
$trigger = New-ScheduledTaskTrigger -Once -At (Get-Date).AddMinutes(1) -RepetitionInterval (New-TimeSpan -Minutes 15) -RepetitionDuration (New-TimeSpan -Days 3650)
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable
Register-ScheduledTask -TaskName "Mimir Claw" -Action $action -Trigger $trigger -Settings $settings
```

Or use the provided `setup-task.ps1` script (run as Admin):
```powershell
.\setup-task.ps1
```

### Uninstall
```powershell
.\install.ps1 -Uninstall
```

---

## Configuration

All config via environment variables:

| Variable | Default | What |
|---|---|---|
| `MIMIR_WORKSPACE` | `~/.openclaw/workspace` | Where to write `memory/*.md` |
| `MIMIR_AGENTS_DIR` | `~/.openclaw/agents` | Where OpenClaw sessions live |
| `MIMIR_AGENTS` | `main` | Comma-separated agent allowlist |
| `MIMIR_TZ` | system local | IANA tz name (e.g. `Australia/Sydney`) |

In Windows, set these via:
```powershell
[Environment]::SetEnvironmentVariable("MIMIR_WORKSPACE", "C:\Users\You\.openclaw\workspace", "User")
```

---

## Teach your agent to use it

Add to your agent's `AGENTS.md`:
```markdown
At the start of every session, read:
- memory/YYYY-MM-DD-chats.md (today)
- memory/<yesterday>-chats.md
```

---

## License

MIT. See [LICENSE](LICENSE).
