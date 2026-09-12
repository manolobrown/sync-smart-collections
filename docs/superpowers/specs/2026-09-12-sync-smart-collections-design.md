# Plan: Sync Smart Collections — Lightroom Classic plugin

## Context

Lightroom Classic (LrC 15.5.1 installed) cannot sync smart collections to the Lightroom cloud; only regular collections can be synced. The user wants every smart collection to be reachable from mobile/web without manual copying.

The plugin mirrors each smart collection into a regular collection inside a top-level set called **"Synced Smart Collections"**, keeps membership in sync, and follows renames/deletes. A background task polls the catalog because the SDK has **no collection-change observer**. The SDK also has **no API to toggle "Sync with Lightroom"**, so the user enables sync once per mirror by right-clicking it; the plugin notifies when a new mirror appears.

Decisions confirmed by user: mirror ALL smart collections automatically; flat mirror set, same names; rename/delete follow the source; public repo `manolobrown/sync-smart-collections`, MIT, written from scratch (no GPL fork).

Environment facts: `gh` is logged in as manolobrown (active). No `lua` on PATH (optional `brew install lua` for pure-logic tests). Plugins auto-load from `~/Library/Application Support/Adobe/Lightroom/Modules/`. LrLogger file logs land in `~/Documents/LrClassicLogs/<name>.log`.

## File layout

```
sync-smart-collections/
├── .gitignore  LICENSE (MIT)  README.md  CHANGELOG.md
├── docs/superpowers/specs/2026-09-12-sync-smart-collections-design.md   (this plan, as the spec)
├── scripts/install.sh            # symlink .lrplugin into ~/Library/.../Lightroom/Modules/
├── tests/                        # pure-Lua only; run.sh, t.lua, test_diff.lua, test_mapping_codec.lua, test_reconciler.lua
└── SyncSmartCollections.lrplugin/
    ├── Info.lua                  # LrSdkVersion 13.0, min 10.0; id com.manolobrown.lightroom.syncsmartcollections;
    │                             # LrInitPlugin, LrShutdownPlugin, LrEnablePlugin, LrDisablePlugin, LrForceInitPlugin=true,
    │                             # LrPluginInfoProvider, LrExportMenuItems: "Sync Now", "Show Log"
    ├── InitPlugin.lua            # Prefs defaults, log "init", Scheduler.start()
    ├── ShutdownPlugin.lua        # return { LrShutdownFunction = function(done, progress) Scheduler.stop(done) end }
    ├── EnablePlugin.lua / DisablePlugin.lua   # Scheduler.start() / Scheduler.stop()
    ├── PluginInfoProvider.lua    # settings section in Plug-in Manager (the ONLY settings UI)
    ├── MenuSyncNow.lua  MenuShowLog.lua
    ├── Log.lua  Prefs.lua  Notifier.lua
    ├── Scheduler.lua             # background loop
    ├── CatalogWalker.lua         # recursive smart-collection snapshot
    ├── MirrorRegistry.lua        # mapping persistence + mirror set lookup
    ├── SyncEngine.lua            # applies plan + membership sync (all catalog writes)
    ├── Reconciler.lua            # PURE: snapshot + mapping -> action plan
    ├── Diff.lua                  # PURE: id-set diff
    └── MappingCodec.lua          # PURE: mapping table <-> string
```

Pure modules never `import` Lr modules and only handle plain tables of ids/names, so they run under Homebrew Lua 5.4 and LrC's Lua 5.1 (avoid `goto`, `unpack`, integer division).

## Modules

- **Prefs.lua** — `Prefs.get()` returns `LrPrefs.prefsForPlugin()` with defaults: `enabled=true`, `intervalSeconds=60` (clamp 10–600), `pauseInDevelop=true`, `notifyStyle="dialog"` (`dialog|bezel|none`), `verboseLogging=false`.
- **Log.lua** — LrLogger `"SyncSmartCollections"` with `enable("logfile")`; `info/warn/error/trace`; `Log.path()`.
- **Diff.lua** — `Diff.compute(sourceIds, mirrorIds) -> toAdd, toRemove` (sorted arrays).
- **MappingCodec.lua** — `encode({[smartId]=mirrorId}) -> "v1|1:2,3:4"`, `decode(str)` tolerant of nil/garbage → `{}`. Needed because `catalog:setPropertyForPlugin` stores scalars only.
- **CatalogWalker.lua** — `snapshot(catalog, mirrorSet)` (async task only) → `{ smarts = {{id,name,parentName,collection}}, mirrorSetChildren = {{id,name,isSmart,collection}} }`. Walks `getChildCollections()/getChildCollectionSets()` recursively, does not descend into the mirror set, `LrTasks.yield()` periodically.
- **MirrorRegistry.lua** — `load(catalog)`/`save(catalog, mapping)` via `getPropertyForPlugin`/`setPropertyForPlugin("mapping")` inside `withPrivateWriteAccessDo`; `ensureMirrorSet(catalog)` looks up stored `"mirrorSetId"` (survives user rename) else `createCollectionSet("Synced Smart Collections", nil, true)`; `resolveMirrors(catalog, mapping)` via `getCollectionByLocalIdentifier`.
- **Reconciler.lua** — `plan{smarts, mapping, mirrorsById, mirrorSetChildren}` → `{actions, mapping, warnings}`. Actions: `create{smartId,name}`, `adopt{smartId,mirrorId}`, `rename{mirrorId,name}`, `delete{mirrorId}`, `unmap{smartId}`.
- **SyncEngine.lua** — `runCycle(reason)` → `{created={names}, changed=n, errors=n, durationMs}`: snapshot → load mapping → plan → apply structure actions in one `withWriteAccessDo("Sync Smart Collections: update mirrors")` (only if actions exist) → save mapping → membership sync → `Notifier.mirrorsCreated`.
  Membership sync: per pair, `Diff.compute` on `getPhotos()` localIdentifiers; ops chunked 500 per `addPhotos/removePhotos`; write blocks capped ~2000 ops with `{timeout=15}`; no write block when nothing changed (no undo noise). Timeout/busy → log and retry next cycle.
- **Scheduler.lua** — state `running, busy, stopRequested, wakeRequested, generation`. `start()` (no-op if running) launches `LrTasks.startAsyncTask` loop: sleep in 1 s slices until interval elapsed or wake/stop; skip if `not prefs.enabled` or (`pauseInDevelop` and `LrApplicationView.getCurrentModuleName()=="develop"`); each cycle inside `LrTasks.pcall`. `stop(done)` sets flag, waits ≤20 s, calls `done()`. `syncNow()` — if busy, bezel "already running"; else wake the loop (or run directly if loop not running). `status()` for the settings section.
- **Notifier.lua** — `mirrorsCreated(names)`: `dialog` → `LrDialogs.message("Sync Smart Collections created N mirror(s)", list + "Right-click each in 'Synced Smart Collections' and choose Sync with Lightroom.", "info")`; `bezel` → `LrDialogs.showBezel(...)`; `none` → nothing.
- **PluginInfoProvider.lua** — `sectionsForTopOfDialog`: enabled, interval, pauseInDevelop, notifyStyle popup, verboseLogging, status line, "Sync Now" / "Show Log" buttons; `bind_to_object = prefs`.

## Reconciliation algorithm (Reconciler.plan)

1. Ignore smart collections located inside the mirror set (warn once).
2. Stale mappings (smartId no longer exists): `delete` mirror if it resolves, then `unmap`. Covers deletes that happened while LrC/plugin was off.
3. Mapping whose mirror no longer resolves (user deleted the mirror or the whole set): `unmap`, treat smart as new → recreated + notified (sync flag is lost, so user must re-enable).
4. Adopt orphans by name: unmapped smart with a same-named regular collection in the mirror set not referenced by any mapping → `adopt` (guards against duplicates if mapping is lost). Other unmanaged collections in the set are never deleted, only logged.
5. Desired names with collision handling: process smarts sorted by localIdentifier (older keeps plain name); on clash try `name (ParentSetName)`, then `name (2)`, `(3)`… Names of unmanaged collections in the set count as claimed.
6. Unmapped smart → `create`. 7. Mapped mirror whose name ≠ desired → `rename`.

Mirror moved out of the set by the user is tracked by id and left alone. Photos added to a mirror by hand are removed next cycle (mirror is source-authoritative; document in README).

## Development workflow

- Add plugin via Plug-in Manager > Add > `SyncSmartCollections.lrplugin` (dev). Reload after `.lua` edits with Plug-in Manager > Plug-in Author Tools > Reload Plug-in. `Info.lua` changes require an LrC restart. `LrShutdownPlugin` fires on reload/disable, not on app quit; the `generation` counter kills zombie loops.
- Watch `tail -f ~/Documents/LrClassicLogs/SyncSmartCollections.log`. Test in a throwaway catalog (File > New Catalog) with a few hundred photos.

## Implementation steps

1. Scaffold: `.gitignore`, `LICENSE`, minimal `README.md`, spec copy under `docs/superpowers/specs/`, `Info.lua`, `Log.lua`, `InitPlugin.lua` (logs only), `ShutdownPlugin.lua` (calls `done()`). Load in LrC, confirm log line. Spike: check whether `withPrivateWriteAccessDo` permits `addPhotos` (if yes, use it for membership sync to keep undo clean; else `withWriteAccessDo`). `git init -b main`, initial commit, then:
   ```
   gh repo create manolobrown/sync-smart-collections --public --source=. --push \
     --description "Lightroom Classic plugin that mirrors smart collections into regular collections so they can sync to Lightroom cloud"
   ```
2. Pure modules + tests: `Diff`, `MappingCodec`, `Reconciler`, `tests/` (run with `lua` if installed via `brew install lua`; otherwise skip and rely on manual checklist).
3. `Prefs`, `CatalogWalker`, `MirrorRegistry`; temporary Sync Now logs snapshot + mapping. Verify recursion, set creation, mapping survives restart.
4. `SyncEngine.runCycle` driven from Sync Now: structure actions, membership sync, chunking. Checklist 1–6, 12.
5. `Scheduler` loop, pause-in-Develop, single-flight, Enable/Disable/Shutdown. Checklist 7, 9, 10.
6. `Notifier`. Checklist 1, 5.
7. `PluginInfoProvider` settings section, `MenuShowLog`. Checklist 8.
8. Docs + release: full README (manual sync-flag limitation, install, settings, mirrors are overwritten, uninstall), `CHANGELOG.md`, `scripts/install.sh`, tag `v0.1.0`, `gh release create` with zipped `.lrplugin`.

Commit after each step with the session attribution lines.

## Verification (manual checklist in LrC)

1. Fresh catalog, 3 smart collections (one nested) → within one interval the "Synced Smart Collections" set holds 3 mirrors with matching counts; notification lists names.
2. Change a smart rule → mirror membership updates; exactly one undo entry; a no-change cycle adds none.
3. Rename smart collection → mirror renamed. Two "Keepers" in different sets → "Keepers" and "Keepers (SetName)".
4. Delete smart collection → mirror deleted, log shows unmap.
5. Delete a mirror manually → recreated with notification. Delete whole mirror set → recreated.
6. Smart collection inside mirror set → ignored with warning.
7. Sync Now during a cycle → "already running" bezel; idle → runs immediately.
8. Settings changes persist across reopening Plug-in Manager; Develop module with pause on → log "skipped: develop".
9. Disable plugin → loop stops; enable → restarts; quit LrC → no hang.
10. Restart LrC → mapping survives, no duplicate mirrors.
11. Right-click mirror > Sync with Lightroom → appears on lightroom.adobe.com / mobile; rule change propagates.
12. 5k+ photo smart collection → completes across cycles without timeout dialog.
