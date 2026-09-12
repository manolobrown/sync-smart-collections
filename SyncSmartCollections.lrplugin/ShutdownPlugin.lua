-- ShutdownPlugin.lua - invoked when the plug-in is reloaded or disabled.

local Scheduler = require "Scheduler"

return {
	LrShutdownFunction = function(doneFunction, progressFunction)
		if progressFunction then progressFunction(0, "Stopping background sync") end
		Scheduler.stop(doneFunction)
	end,
}
