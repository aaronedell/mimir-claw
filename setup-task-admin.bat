@echo off
setlocal enabledelayedexpansion
echo ========================================
echo Mimir Claw - Task Scheduler Setup
echo ========================================
echo.
echo This will create a scheduled task to run
echo Mimir Claw every 15 minutes.
echo.
echo Press any key to continue...
pause >nul

REM Find Python
set "PYTHON="
for %%i in (python.exe python3.exe) do (
    if "!PYTHON!"=="" (
        set "PYTHON=%%~$PATH:i"
    )
)

if "%PYTHON%"=="" (
    echo ERROR: Python not found in PATH.
    echo Please install Python 3.9+ from python.org
echo.
    pause
    exit /b 1
)

echo Found Python: %PYTHON%

REM Delete existing task if present
schtasks /delete /tn "Mimir Claw" /f 2>nul

REM Create the task (runs every 15 min for 10 years)
schtasks /create /tn "Mimir Claw" /tr "\"%PYTHON%\" \"%USERPROFILE%\.local\share\mimir-claw\chat_sweeper.py\"" /sc minute /mo 15 /ru "%USERNAME%" /f

if %errorlevel% neq 0 (
    echo.
    echo ERROR: Failed to create task.
    echo.
    pause
    exit /b 1
)

echo.
echo ========================================
echo SUCCESS! Task created.
echo ========================================
echo.
echo Mimir Claw will run every 15 minutes.
echo.
echo To check: Open Task Scheduler (taskschd.msc)
echo To remove: schtasks /delete /tn "Mimir Claw" /f
echo.
pause
