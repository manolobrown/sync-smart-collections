-- Prefs.lua - plug-in preferences with defaults

local LrPrefs = import "LrPrefs"

local Prefs = {}

Prefs.MIN_INTERVAL = 10
Prefs.MAX_INTERVAL = 600
Prefs.MIRROR_SET_NAME = "Synced Smart Collections"

local defaults = {
	enabled = true,
	intervalSeconds = 60,
	pauseInDevelop = true,
	notifyStyle = "dialog", -- "dialog" | "bezel" | "none"
	verboseLogging = false,
}

local prefs

function Prefs.get()
	if not prefs then
		prefs = LrPrefs.prefsForPlugin()
		for k, v in pairs(defaults) do
			if prefs[k] == nil then prefs[k] = v end
		end
	end
	return prefs
end

function Prefs.interval()
	local p = Prefs.get()
	local n = tonumber(p.intervalSeconds) or defaults.intervalSeconds
	if n < Prefs.MIN_INTERVAL then n = Prefs.MIN_INTERVAL end
	if n > Prefs.MAX_INTERVAL then n = Prefs.MAX_INTERVAL end
	return n
end

return Prefs
