#!/usr/bin/env bash
# Symlinks the plug-in into Lightroom Classic's auto-load Modules folder (macOS).
# Lightroom loads it on next launch; it also appears in File > Plug-in Manager.
set -euo pipefail
REPO="$(cd "$(dirname "$0")/.." && pwd)"
MODULES="$HOME/Library/Application Support/Adobe/Lightroom/Modules"
mkdir -p "$MODULES"
ln -sfn "$REPO/SyncSmartCollections.lrplugin" "$MODULES/SyncSmartCollections.lrplugin"
echo "Installed: $MODULES/SyncSmartCollections.lrplugin -> $REPO/SyncSmartCollections.lrplugin"
echo "Restart Lightroom Classic (or Plug-in Manager > Reload Plug-in if already listed)."
