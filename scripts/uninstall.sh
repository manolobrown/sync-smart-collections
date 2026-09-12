#!/usr/bin/env bash
# Removes the symlink created by install.sh. Mirror collections in your catalog are left untouched.
set -euo pipefail
rm -f "$HOME/Library/Application Support/Adobe/Lightroom/Modules/SyncSmartCollections.lrplugin"
echo "Removed plug-in symlink. Restart Lightroom Classic."
