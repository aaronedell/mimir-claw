#!/usr/bin/env bash
# Mimir Claw installer
# Usage:
#   ./install.sh            # install
#   ./install.sh --uninstall
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_DIR="${HOME}/.local/share/mimir-claw"
SCRIPT_DEST="${INSTALL_DIR}/chat_sweeper.py"
PLIST_LABEL="com.openclaw.mimir-claw"
PLIST_DEST="${HOME}/Library/LaunchAgents/${PLIST_LABEL}.plist"

OPENCLAW_WORKSPACE_DEFAULT="${HOME}/.openclaw/workspace"
OPENCLAW_AGENTS_DEFAULT="${HOME}/.openclaw/agents"

uninstall() {
    echo "Uninstalling Mimir Claw..."
    if [[ "$(uname -s)" == "Darwin" && -f "${PLIST_DEST}" ]]; then
        launchctl unload "${PLIST_DEST}" 2>/dev/null || true
        rm -f "${PLIST_DEST}"
        echo "  ✓ Removed LaunchAgent"
    fi
    if [[ -d "${INSTALL_DIR}" ]]; then
        rm -rf "${INSTALL_DIR}"
        echo "  ✓ Removed ${INSTALL_DIR}"
    fi
    echo "Done. (Your memory/*.md files were NOT deleted.)"
    exit 0
}

if [[ "${1:-}" == "--uninstall" ]]; then
    uninstall
fi

echo "Installing Mimir Claw..."

# Find python3
PYTHON_BIN="$(command -v python3 || true)"
if [[ -z "${PYTHON_BIN}" ]]; then
    echo "ERROR: python3 not found. Install Python 3.9+ first." >&2
    exit 1
fi

# Copy script
mkdir -p "${INSTALL_DIR}"
cp "${REPO_DIR}/chat_sweeper.py" "${SCRIPT_DEST}"
chmod +x "${SCRIPT_DEST}"
echo "  ✓ Installed script to ${SCRIPT_DEST}"

# Determine workspace & agents dirs
WORKSPACE="${MIMIR_WORKSPACE:-${OPENCLAW_WORKSPACE_DEFAULT}}"
AGENTS="${MIMIR_AGENTS_DIR:-${OPENCLAW_AGENTS_DEFAULT}}"

if [[ ! -d "${AGENTS}" ]]; then
    echo "  ⚠ OpenClaw agents dir not found at ${AGENTS}"
    echo "    Set MIMIR_AGENTS_DIR env var and re-run if your install differs."
fi

mkdir -p "${WORKSPACE}/memory"

# Run once to verify
echo "  ▸ Running once to verify..."
MIMIR_WORKSPACE="${WORKSPACE}" MIMIR_AGENTS_DIR="${AGENTS}" \
    "${PYTHON_BIN}" "${SCRIPT_DEST}" || {
    echo "ERROR: chat_sweeper.py failed. See output above." >&2
    exit 1
}

# Platform-specific scheduler
OS="$(uname -s)"
if [[ "${OS}" == "Darwin" ]]; then
    mkdir -p "${HOME}/Library/LaunchAgents"
    sed \
        -e "s|__PYTHON__|${PYTHON_BIN}|g" \
        -e "s|__SCRIPT__|${SCRIPT_DEST}|g" \
        -e "s|__WORKSPACE__|${WORKSPACE}|g" \
        -e "s|__AGENTS_DIR__|${AGENTS}|g" \
        "${REPO_DIR}/com.openclaw.mimir-claw.plist.template" > "${PLIST_DEST}"
    launchctl unload "${PLIST_DEST}" 2>/dev/null || true
    launchctl load "${PLIST_DEST}"
    echo "  ✓ Installed LaunchAgent at ${PLIST_DEST} (runs every 15 min)"
else
    echo ""
    echo "  ℹ Linux detected. Add this line to your crontab (crontab -e):"
    echo ""
    echo "    */15 * * * * MIMIR_WORKSPACE='${WORKSPACE}' MIMIR_AGENTS_DIR='${AGENTS}' ${PYTHON_BIN} ${SCRIPT_DEST} >> /tmp/mimir-claw.log 2>&1"
    echo ""
fi

echo ""
echo "✓ Mimir Claw installed."
echo "  Logs:        ${WORKSPACE}/memory/YYYY-MM-DD-chats.md"
echo "  Config env:  MIMIR_WORKSPACE, MIMIR_AGENTS_DIR, MIMIR_AGENTS, MIMIR_TZ"
echo "  Uninstall:   ${REPO_DIR}/install.sh --uninstall"
