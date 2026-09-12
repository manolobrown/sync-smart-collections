# Sync Smart Collections (Lightroom Classic plug-in)

Lightroom Classic cannot sync **smart collections** to the Lightroom cloud; only regular
collections can be synced. This plug-in mirrors every smart collection into a regular
collection inside a top-level set called **Synced Smart Collections**, keeps the photos in
sync in the background, and follows renames and deletes. Turn on *Sync with Lightroom* on a
mirror once and that smart collection is available in Lightroom on every device.

## How it works

1. A background task checks the catalog every 60 seconds (configurable).
2. Every smart collection gets a same-named regular collection inside **Synced Smart Collections**.
   A name clash gets the parent set appended, e.g. `Keepers (2024)`, then `(2)`, `(3)`.
3. Photo membership is diffed and only the changes are written, so unchanged cycles add
   nothing to the Undo history.
4. Rename a smart collection and the mirror is renamed. Delete it and the mirror is deleted.
   Delete a mirror by hand and it is recreated on the next cycle.
5. When a new mirror is created you get a dialog listing it. **Right-click the mirror and
   choose "Sync with Lightroom"**: the SDK has no way to do that step for you.

## Install

Requires Lightroom Classic 10 or later on macOS or Windows.

**macOS, from a clone:**

```sh
git clone https://github.com/manolobrown/sync-smart-collections.git
cd sync-smart-collections
./scripts/install.sh
```

**Any platform:** download the repository, then in Lightroom Classic open
*File > Plug-in Manager*, click *Add*, and choose the `SyncSmartCollections.lrplugin` folder.

Restart Lightroom Classic after installing. The first sync runs a few seconds after launch.

## Settings

Open *File > Plug-in Manager* and select *Sync Smart Collections*:

| Setting | Default | Notes |
| --- | --- | --- |
| Enable background sync | on | Turn off to only sync via *Sync Now*. |
| Check for changes every | 60 s | 10 to 600 seconds. |
| Pause while the Develop module is active | on | Avoids Undo-history noise while editing. |
| When a new mirror is created | dialog | `dialog`, brief on-screen message, or nothing. |
| Verbose logging | off | Adds per-collection detail to the log. |

Menu items under *File > Plug-in Extras*: **Sync Now** and **Show Log**.

## Things to know

- Mirrors are owned by the plug-in. Photos you add to a mirror by hand are removed on the
  next cycle; add them to the smart collection's criteria instead.
- The mapping between smart collections and mirrors is stored inside the catalog, so it
  survives restarts. If it is ever lost, mirrors are re-adopted by name rather than duplicated.
- Smart collections placed inside **Synced Smart Collections** are ignored.
- Log file: `~/Documents/LrClassicLogs/SyncSmartCollections.log`
  (Windows: `Documents\LrClassicLogs\SyncSmartCollections.log`).

## Development

```sh
brew install lua      # tests need a plain Lua interpreter
./tests/run.sh        # pure logic tests plus a stubbed-Lightroom engine test
```

After editing `.lua` files, use *Plug-in Manager > Plug-in Author Tools > Reload Plug-in*.
Changes to `Info.lua` need a Lightroom restart. Design notes live in `docs/superpowers/specs/`.

## License

MIT. See `LICENSE`.
