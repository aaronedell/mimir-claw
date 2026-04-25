#Requires -Version 5.1
<#
.SYNOPSIS
    Mimir Claw installer for Windows
.DESCRIPTION
    Installs Mimir Claw (OpenClaw memory sweeper) on Windows.
    Creates scheduled task, sets up directories, and configures environment.
.PARAMETER Uninstall
    Removes Mimir Claw and its scheduled task
.EXAMPLE
    .\install.ps1
    .\install.ps1 -Uninstall
#>
[CmdletBinding()]
param(
    [switch]$Uninstall
)

$ErrorActionPreference = "Stop"

# Paths
$RepoDir = $PSScriptRoot
if (-not $RepoDir) { $RepoDir = (Get-Location).Path }
$InstallDir = Join-Path $env:USERPROFILE ".local\share\mimir-claw"
$ScriptDest = Join-Path $InstallDir "chat_sweeper.py"
$OpenClawWorkspaceDefault = Join-Path $env:USERPROFILE ".openclaw\workspace"
$OpenClawAgentsDefault = Join-Path $env:USERPROFILE ".openclaw\agents"

function Test-Python {
    $python = Get-Command "python" -ErrorAction SilentlyContinue
    if (-not $python) {
        $python = Get-Command "python3" -ErrorAction SilentlyContinue
    }
    if (-not $python) {
        Write-Error "Python not found. Install Python 3.9+ from python.org and add to PATH."
        exit 1
    }
    return $python.Source
}

function Uninstall-MimirClaw {
    Write-Host "Uninstalling Mimir Claw..." -ForegroundColor Yellow
    
    # Remove scheduled task
    $task = Get-ScheduledTask -TaskName "Mimir Claw" -ErrorAction SilentlyContinue
    if ($task) {
        Unregister-ScheduledTask -TaskName "Mimir Claw" -Confirm:$false
        Write-Host "  [OK] Removed scheduled task 'Mimir Claw'" -ForegroundColor Green
    }
    
    # Remove install directory
    if (Test-Path $InstallDir) {
        Remove-Item -Path $InstallDir -Recurse -Force
        Write-Host "  [OK] Removed $InstallDir" -ForegroundColor Green
    }
    
    Write-Host "`nDone. Your memory/*.md files were NOT deleted." -ForegroundColor Cyan
    exit 0
}

if ($Uninstall) {
    Uninstall-MimirClaw
}

Write-Host "Installing Mimir Claw for Windows..." -ForegroundColor Cyan
Write-Host ""

# Check Python
$PythonBin = Test-Python
Write-Host "  [OK] Found Python: $PythonBin" -ForegroundColor Green

# Create directories
New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null
Write-Host "  [OK] Created $InstallDir" -ForegroundColor Green

# Copy script
Copy-Item -Path (Join-Path $RepoDir "chat_sweeper.py") -Destination $ScriptDest -Force
Write-Host "  [OK] Installed script to $ScriptDest" -ForegroundColor Green

# Determine workspace & agents dirs
$Workspace = if ($env:MIMIR_WORKSPACE) { $env:MIMIR_WORKSPACE } else { $OpenClawWorkspaceDefault }
$Agents = if ($env:MIMIR_AGENTS_DIR) { $env:MIMIR_AGENTS_DIR } else { $OpenClawAgentsDefault }

# Check if agents dir exists
if (-not (Test-Path $Agents)) {
    Write-Host "  [WARN] OpenClaw agents dir not found at $Agents" -ForegroundColor Yellow
    Write-Host "         Set MIMIR_AGENTS_DIR environment variable if your install differs." -ForegroundColor Yellow
}

# Create memory directory
$MemoryDir = Join-Path $Workspace "memory"
New-Item -ItemType Directory -Path $MemoryDir -Force | Out-Null
Write-Host "  [OK] Created/verified memory directory: $MemoryDir" -ForegroundColor Green

# Run once to verify
Write-Host ""
Write-Host "Running once to verify..." -ForegroundColor Cyan
$env:MIMIR_WORKSPACE = $Workspace
$env:MIMIR_AGENTS_DIR = $Agents
try {
    & $PythonBin $ScriptDest
    Write-Host "  [OK] chat_sweeper.py ran successfully" -ForegroundColor Green
}
catch {
    Write-Error "chat_sweeper.py failed: $_"
    exit 1
}

# Create scheduled task
Write-Host ""
Write-Host "Creating scheduled task..." -ForegroundColor Cyan
try {
    $TaskName = "Mimir Claw"
    $TaskDescription = "Mimir Claw - OpenClaw memory sweeper (runs every 15 min)"
    
    # Remove existing task if present
    $existing = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
    if ($existing) {
        Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
    }
    
    # Create action
    $Action = New-ScheduledTaskAction -Execute $PythonBin -Argument "`"$ScriptDest`""
    
    # Create trigger (every 15 minutes, starting now, run indefinitely)
    $StartTime = (Get-Date).AddMinutes(1)
    $Trigger = New-ScheduledTaskTrigger -Once -At $StartTime -RepetitionInterval (New-TimeSpan -Minutes 15) -RepetitionDuration (New-TimeSpan -Days 3650)
    
    # Create settings
    $Settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable -RunOnlyIfNetworkAvailable:$false
    
    # Register task
    Register-ScheduledTask -TaskName $TaskName -Action $Action -Trigger $Trigger -Settings $Settings -Description $TaskDescription | Out-Null
    
    Write-Host "  [OK] Created scheduled task '$TaskName' (runs every 15 minutes)" -ForegroundColor Green
    Write-Host "       View in Task Scheduler: taskschd.msc" -ForegroundColor Gray
}
catch {
    Write-Host "  [WARN] Could not create scheduled task (may need admin rights)" -ForegroundColor Yellow
    Write-Host "         To create manually, run setup-task.ps1 as Administrator:" -ForegroundColor Yellow
    Write-Host "         .\setup-task.ps1" -ForegroundColor Yellow
}

# Summary
Write-Host ""
Write-Host "Mimir Claw installed successfully!" -ForegroundColor Green
Write-Host ""
Write-Host "Configuration:" -ForegroundColor Cyan
Write-Host "  Logs:        $MemoryDir\YYYY-MM-DD-chats.md"
Write-Host "  Script:      $ScriptDest"
Write-Host "  Config env:  MIMIR_WORKSPACE, MIMIR_AGENTS_DIR, MIMIR_AGENTS, MIMIR_TZ"
Write-Host ""
Write-Host "Uninstall:    .\install.ps1 -Uninstall"
Write-Host ""
