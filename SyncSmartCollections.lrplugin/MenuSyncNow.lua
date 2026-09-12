local LrTasks = import "LrTasks"
local Scheduler = require "Scheduler"

LrTasks.startAsyncTask(function()
	Scheduler.syncNow()
end, "SyncSmartCollections manual sync")
