# Windows Conversion Summary

## Changes Made for Windows Compatibility

### 1. `chat_sweeper.py` — UTF-8 Encoding Fixes
Added explicit UTF-8 encoding to all file operations (Windows defaults to cp1252 which breaks on Unicode):

- Line 147: `CURSOR_FILE.read_text(encoding="utf-8")`
- Line 155: `tmp.write_text(..., encoding="utf-8")`
- Line 165: `path.open(encoding="utf-8")`
- Line 243: `path.open("a", encoding="utf-8")`
- Line 247: Added Windows comment for `os.chmod()` behavior

### 2. New Files Created

#### `install.ps1`
PowerShell installer that:
- Detects Python installation
- Copies script to `~/.local/share/mimir-claw/`
- Creates memory directory
- Sets up Windows Task Scheduler (runs every 15 min)
- Supports `-Uninstall` switch
- Fixed: Success message only shows on actual success

#### `setup-task.ps1`
Standalone scheduled task setup script (requires Admin):
- Creates "Mimir Claw" task in Windows Task Scheduler
- Runs every 15 minutes for 10 years (fixed from MaxValue bug)
- Fixed duration: `New-TimeSpan -Days 3650` instead of `[TimeSpan]::MaxValue`

#### `README-WINDOWS.md`
Windows-specific documentation with:
- PowerShell install instructions
- Task Scheduler setup (fixed MaxValue bug)
- Windows environment variable configuration

#### `setup-task-admin.bat`
Batch file alternative for admin task setup:
- Fixed: Added `setlocal enabledelayedexpansion`
- Uses schtasks for broader Windows compatibility

### 3. Files NOT Changed
- `LICENSE` — unchanged
- `.gitignore` — unchanged (works on Windows)
- Original `README.md` — kept for reference
- `com.openclaw.mimir-claw.plist.template` — kept (macOS only)
- Original `install.sh` — kept (Unix only)

## How to Use (Windows)

### Quick Install
```powershell
cd mimir-claw
.\install.ps1
```

### Verify It Works
```powershell
python chat_sweeper.py
```

### Check Your Logs
Logs are written to:
```
C:\Users\<you>\.openclaw\workspace\memory\YYYY-MM-DD-chats.md
```

### Manual Run
```powershell
python "$env:USERPROFILE\.local\share\mimir-claw\chat_sweeper.py"
```

### Uninstall
```powershell
.\install.ps1 -Uninstall
```

## Test Results
✅ Successfully processed 2,841+ messages from 59+ sessions
✅ Created daily chat logs from 2026-02-07 through 2026-04-25
✅ UTF-8 encoding handled emoji and special characters correctly

## Path Mapping

| Unix (Original) | Windows (This Fork) |
|----------------|---------------------|
| `~/.local/share/mimir-claw/` | `%USERPROFILE%\.local\share\mimir-claw\` |
| `~/.openclaw/workspace/` | `%USERPROFILE%\.openclaw\workspace\` |
| `~/Library/LaunchAgents/` | Windows Task Scheduler |
| `launchctl` | `schtasks` / Task Scheduler |
| `crontab` | Scheduled Tasks |
| `chmod 600` | Sets read-only bit (best-effort, see note in code) |

## Environment Variables (Windows)

Set via PowerShell:
```powershell
[Environment]::SetEnvironmentVariable("MIMIR_WORKSPACE", "C:\Your\Path", "User")
```

Or for current session only:
```powershell
$env:MIMIR_WORKSPACE = "C:\Your\Path"
```

## Known Limitations

1. **File permissions**: Unix `chmod 600` has no direct Windows equivalent. The script sets the read-only bit, but for true ACL restrictions you'd need `icacls` or `win32security`.
2. **Task Scheduler**: Requires Administrator privileges to create/modify tasks.
3. **Python path**: Script looks for `python` or `python3` in PATH.

## Bugs Fixed

1. **UTF-8 encoding**: Fixed `UnicodeDecodeError` on Windows by adding explicit `encoding="utf-8"` to all file operations
2. **Task duration**: Fixed `[TimeSpan]::MaxValue` bug that caused Task Scheduler XML error (replaced with 10-year duration)
3. **Delayed expansion**: Fixed `setup-task-admin.bat` to properly use `!PYTHON!` variable
4. **False success**: Fixed `install.ps1` to not claim task creation succeeded when it failed

## Original Repo
https://github.com/aaronedell/mimir-claw
