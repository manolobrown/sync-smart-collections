--[[
  Sync Smart Collections - Lightroom Classic plug-in
  Mirrors every smart collection into a regular collection so it can be
  synced to Lightroom cloud (mobile / web).
]]

return {
	LrSdkVersion = 13.0,
	LrSdkMinimumVersion = 10.0,

	LrToolkitIdentifier = "com.manolobrown.lightroom.syncsmartcollections",
	LrPluginName = "Sync Smart Collections",
	LrPluginInfoUrl = "https://github.com/manolobrown/sync-smart-collections",

	LrInitPlugin = "InitPlugin.lua",
	LrShutdownPlugin = "ShutdownPlugin.lua",
	LrEnablePlugin = "EnablePlugin.lua",
	LrDisablePlugin = "DisablePlugin.lua",
	LrForceInitPlugin = true,

	LrPluginInfoProvider = "PluginInfoProvider.lua",

	LrExportMenuItems = {
		{ title = "Sync Smart Collections: Sync Now", file = "MenuSyncNow.lua" },
		{ title = "Sync Smart Collections: Show Log", file = "MenuShowLog.lua" },
	},

	VERSION = { major = 0, minor = 1, revision = 0, build = 1 },
}
