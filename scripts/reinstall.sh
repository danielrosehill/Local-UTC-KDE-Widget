#!/usr/bin/env bash
set -euo pipefail

# Reinstall this Plasma applet from the current repo directory.
# - Uninstalls any existing copy by plugin Id
# - Installs the package from this directory
# - Optional: restart plasmashell with --restart
#
# Usage: scripts/reinstall.sh [--restart]

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"

RESTART=false
if [[ "${1:-}" == "--restart" ]]; then
  RESTART=true
fi

# Pick kpackagetool for Plasma 6 or 5
if command -v kpackagetool6 >/dev/null 2>&1; then
  KPK=kpackagetool6
elif command -v kpackagetool5 >/dev/null 2>&1; then
  KPK=kpackagetool5
else
  echo "Error: kpackagetool6/kpackagetool5 not found in PATH" >&2
  exit 1
fi

# Extract plugin Id from metadata.json, fallback to known Id
ID=$(grep -Po '"Id"\s*:\s*"([^"]+)' "$ROOT/metadata.json" | head -1 | cut -d'"' -f4 || true)
if [[ -z "${ID:-}" ]]; then
  ID="local-utc-kde-widget"
fi

echo "Using $KPK"
echo "Plugin Id: $ID"
echo "Source dir: $ROOT"

echo "Uninstalling previous version (if present)..."
if ! "$KPK" -t Plasma/Applet -r "$ID" 2>/dev/null; then
  echo "(Nothing to remove)"
fi

echo "Installing from $ROOT ..."
if ! "$KPK" -t Plasma/Applet -i "$ROOT"; then
  echo "Install failed, attempting upgrade instead..."
  "$KPK" -t Plasma/Applet -u "$ROOT"
fi

echo "Reinstalled: $ID"

if $RESTART; then
  echo "Restarting plasmashell (this will briefly flicker the desktop)..."
  if command -v kquitapp6 >/dev/null 2>&1; then
    kquitapp6 plasmashell || true
  elif command -v kquitapp5 >/dev/null 2>&1; then
    kquitapp5 plasmashell || true
  fi
  # --replace works on both X11 and Wayland for recent Plasma
  (plasmashell --replace >/dev/null 2>&1 & disown) || true
  echo "plasmashell restart requested. If it didn't refresh, log out/in."
else
  echo "Note: plasmashell may cache widgets. If changes don't appear, run with --restart."
fi

echo "Done."

