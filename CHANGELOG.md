# Changelog

## 0.1.0 - 2026-09-12

- Initial release.
- Mirrors every smart collection into a regular collection under "Synced Smart Collections".
- Background sync at a configurable interval (10-600 s), paused while in Develop by default.
- Follows renames and deletes; recreates mirrors you delete by hand; adopts orphaned mirrors by name.
- Notification (dialog, bezel or none) when a new mirror needs "Sync with Lightroom" enabled.
- Settings in File > Plug-in Manager; "Sync Now" and "Show Log" under File > Plug-in Extras.
