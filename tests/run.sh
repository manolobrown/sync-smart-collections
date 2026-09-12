#!/usr/bin/env bash
# Runs the pure-Lua unit tests. Requires `lua` (brew install lua).
set -u
cd "$(dirname "$0")/.."
status=0
for f in tests/test_*.lua; do
	if ! lua -e 'package.path="./SyncSmartCollections.lrplugin/?.lua;./tests/?.lua;"..package.path' "$f"; then
		status=1
	fi
done
exit $status
