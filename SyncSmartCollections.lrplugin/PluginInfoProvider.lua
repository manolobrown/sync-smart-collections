-- PluginInfoProvider.lua - settings section shown in File > Plug-in Manager.

local LrView = import "LrView"
local LrTasks = import "LrTasks"
local LrShell = import "LrShell"

local Prefs = require "Prefs"
local Log = require "Log"
local Scheduler = require "Scheduler"

local bind = LrView.bind

return {
	sectionsForTopOfDialog = function(f, propertyTable)
		local prefs = Prefs.get()
		propertyTable.status = Scheduler.statusText()

		local function refreshStatus()
			propertyTable.status = Scheduler.statusText()
		end

		return {
			{
				title = "Sync Smart Collections",
				bind_to_object = prefs,

				f:row {
					f:checkbox { title = "Enable background sync", value = bind "enabled" },
				},
				f:row {
					spacing = f:label_spacing(),
					f:static_text { title = "Check for changes every" },
					f:edit_field {
						value = bind "intervalSeconds",
						min = Prefs.MIN_INTERVAL, max = Prefs.MAX_INTERVAL, precision = 0,
						width_in_digits = 4, immediate = true,
					},
					f:static_text { title = ("seconds (%d-%d)"):format(Prefs.MIN_INTERVAL, Prefs.MAX_INTERVAL) },
				},
				f:row {
					f:checkbox { title = "Pause while the Develop module is active", value = bind "pauseInDevelop" },
				},
				f:row {
					spacing = f:label_spacing(),
					f:static_text { title = "When a new mirror is created:" },
					f:popup_menu {
						value = bind "notifyStyle",
						items = {
							{ title = "Show a dialog", value = "dialog" },
							{ title = "Show a brief on-screen message", value = "bezel" },
							{ title = "Do nothing", value = "none" },
						},
					},
				},
				f:row {
					f:checkbox { title = "Verbose logging", value = bind "verboseLogging" },
				},
				f:row {
					f:push_button {
						title = "Sync Now",
						action = function()
							LrTasks.startAsyncTask(function()
								Scheduler.syncNow()
								refreshStatus()
							end)
						end,
					},
					f:push_button {
						title = "Show Log",
						action = function()
							LrTasks.startAsyncTask(function() LrShell.revealInFinder(Log.path()) end)
						end,
					},
					f:push_button { title = "Refresh Status", action = refreshStatus },
				},
				f:static_text {
					title = bind { key = "status", object = propertyTable },
					width_in_chars = 70,
					height_in_lines = 2,
				},
				f:static_text {
					title = "Mirrors live in the 'Synced Smart Collections' set. Right-click a mirror and choose "
						.. "'Sync with Lightroom' once to make it available on your other devices. "
						.. "Photos added to a mirror by hand are removed on the next sync.",
					width_in_chars = 70,
					height_in_lines = 3,
				},
			},
		}
	end,
}
