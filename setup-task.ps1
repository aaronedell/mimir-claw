#Requires -Version 5.1
#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Standalone Task Scheduler setup for Mimir Claw
.DESCRIPTION
    Creates a Windows Scheduled Task to run Mimir Claw every 15 minutes.
    Run this as Administrator.
.EXAMPLE
    .\setup-task.ps1
#>

$ErrorActionPreference = "Stop"

$InstallDir = Join-Path $env:USERPROFILE ".local\share\mimir-claw"
$ScriptDest = Join-Path $InstallDir "chat_sweeper.py"

# Find Python
$PythonBin = Get-Command "python" -ErrorAction SilentlyContinue
if (-not $PythonBin) {
    $PythonBin = Get-Command "python3" -ErrorAction SilentlyContinue
}
if (-not $PythonBin) {
    Write-Error "Python not found in PATH. Install Python 3.9+ and try again."
    exit 1
}

# Check script exists
if (-not (Test-Path $ScriptDest)) {
    Write-Error "chat_sweeper.py not found at $ScriptDest`nRun install.ps1 first, or check the path."
    exit 1
}

Write-Host "Setting up Mimir Claw scheduled task..." -ForegroundColor Cyan

$TaskName = "Mimir Claw"
$TaskDescription = "Mimir Claw - OpenClaw memory sweeper (runs every 15 min)"

# Remove existing task if present
$existing = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
if ($existing) {
    Write-Host "Removing existing task..." -ForegroundColor Yellow
    Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
}

# Create action
$Action = New-ScheduledTaskAction -Execute $PythonBin.Source -Argument "`"$ScriptDest`""

# Create trigger (every 15 minutes, starting 1 min from now, run for 10 years)
$StartTime = (Get-Date).AddMinutes(1)
$Trigger = New-ScheduledTaskTrigger -Once -At $StartTime -RepetitionInterval (New-TimeSpan -Minutes 15) -RepetitionDuration (New-TimeSpan -Days 3650)

# Create settings
$Settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable -RunOnlyIfNetworkAvailable:$false

# Register task
Register-ScheduledTask -TaskName $TaskName -Action $Action -Trigger $Trigger -Settings $Settings -Description $TaskDescription | Out-Null

Write-Host "[OK] Scheduled task '$TaskName' created successfully!" -ForegroundColor Green
Write-Host ""
Write-Host "The task will run every 15 minutes." -ForegroundColor Cyan
Write-Host "To view/modify: Open Task Scheduler (taskschd.msc)" -ForegroundColor Gray
Write-Host "To run manually: Start-ScheduledTask -TaskName '$TaskName'" -ForegroundColor Gray
Write-Host "To remove: Unregister-ScheduledTask -TaskName '$TaskName' -Confirm:`$false" -ForegroundColor Gray
