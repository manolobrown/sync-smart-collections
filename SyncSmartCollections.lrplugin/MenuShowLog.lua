local LrTasks = import "LrTasks"
local LrShell = import "LrShell"
local LrFileUtils = import "LrFileUtils"
local LrDialogs = import "LrDialogs"
local Log = require "Log"

LrTasks.startAsyncTask(function()
	local path = Log.path()
	if LrFileUtils.exists(path) then
		LrShell.revealInFinder(path)
	else
		LrDialogs.message("No log file yet", "The log will be written to:\n" .. path, "info")
	end
end)
