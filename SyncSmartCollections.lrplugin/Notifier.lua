-- Notifier.lua - user-facing notifications.

local LrDialogs = import "LrDialogs"
local Prefs = require "Prefs"

local Notifier = {}

local SETUP_HINT = "Right-click each one under 'Synced Smart Collections' and choose 'Sync with Lightroom' to make it available on your other devices."

function Notifier.bezel(message)
	if LrDialogs.showBezel then
		LrDialogs.showBezel(message)
	end
end

function Notifier.mirrorsCreated(names)
	local style = Prefs.get().notifyStyle or "dialog"
	if style == "none" or #names == 0 then return end
	local headline = ("Sync Smart Collections created %d new mirror collection%s"):format(#names, #names == 1 and "" or "s")
	if style == "bezel" then
		Notifier.bezel(headline .. ": " .. table.concat(names, ", ") .. ". Enable 'Sync with Lightroom' on each.")
		return
	end
	local list = {}
	for _, n in ipairs(names) do list[#list + 1] = "• " .. n end
	LrDialogs.message(headline, table.concat(list, "\n") .. "\n\n" .. SETUP_HINT, "info")
end

return Notifier
