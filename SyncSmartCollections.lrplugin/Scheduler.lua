-- Scheduler.lua - background polling loop with single-flight execution and clean shutdown.

local LrTasks = import "LrTasks"
local LrApplicationView = import "LrApplicationView"
local LrDate = import "LrDate"

local Prefs = require "Prefs"
local Log = require "Log"
local SyncEngine = require "SyncEngine"
local Notifier = require "Notifier"

local Scheduler = {}

local STARTUP_DELAY = 5 -- seconds before the first cycle after launch

local S = {
	running = false,
	busy = false,
	stopRequested = false,
	wakeRequested = false,
	generation = 0,
	lastRunAt = nil,
	lastResult = nil,
	lastError = nil,
	lastSkip = nil,
}

-- Runs one guarded cycle. Returns true if a cycle ran.
function Scheduler.runCycle(reason)
	if S.busy then return false, "busy" end
	local prefs = Prefs.get()
	Log.setVerbose(prefs.verboseLogging)
	if reason ~= "manual" then
		if not prefs.enabled then
			S.lastSkip = "disabled"
			return false, "disabled"
		end
		if prefs.pauseInDevelop and LrApplicationView.getCurrentModuleName() == "develop" then
			S.lastSkip = "develop"
			Log.trace("skipped: develop module active")
			return false, "develop"
		end
	end

	S.busy = true
	local ok, result = LrTasks.pcall(SyncEngine.runCycle, reason)
	S.busy = false
	S.lastRunAt = LrDate.currentTime()
	S.lastSkip = nil
	if ok then
		S.lastResult, S.lastError = result, nil
	else
		S.lastError = tostring(result)
		Log.error("cycle failed: %s", S.lastError)
	end
	return true, ok and "ok" or "error"
end

function Scheduler.start()
	if S.running then return end
	S.generation = S.generation + 1
	local gen = S.generation
	S.running = true
	S.stopRequested = false

	LrTasks.startAsyncTask(function()
		Log.info("scheduler started (interval %ds)", Prefs.interval())
		local waited = Prefs.interval() - STARTUP_DELAY
		while not S.stopRequested and gen == S.generation do
			LrTasks.sleep(1)
			waited = waited + 1
			if S.wakeRequested or waited >= Prefs.interval() then
				S.wakeRequested = false
				waited = 0
				Scheduler.runCycle("scheduled")
			end
		end
		if gen == S.generation then S.running = false end
		Log.info("scheduler stopped")
	end, "SyncSmartCollections scheduler")
end

-- Stops the loop. If doneFunction is given (plug-in shutdown), waits up to 20s for the loop to exit.
function Scheduler.stop(doneFunction)
	S.stopRequested = true
	S.generation = S.generation + 1
	if not doneFunction then
		S.running = false
		return
	end
	local function waitThenDone()
		local waited = 0
		while S.busy and waited < 20 do
			LrTasks.sleep(0.5)
			waited = waited + 0.5
		end
		S.running = false
		doneFunction()
	end
	if LrTasks.canYield() then
		waitThenDone()
	else
		LrTasks.startAsyncTask(waitThenDone, "SyncSmartCollections shutdown")
	end
end

-- Menu / button entry point. Must be called from an async task.
function Scheduler.syncNow()
	if S.busy then
		Notifier.bezel("Sync Smart Collections: a sync is already running")
		return
	end
	local ran, why = Scheduler.runCycle("manual")
	if ran and why == "ok" and S.lastResult then
		local r = S.lastResult
		Notifier.bezel(("Sync Smart Collections: %d mirror(s), %d created, %d updated"):format(r.mirrors, #r.created, r.changed))
	elseif ran then
		Notifier.bezel("Sync Smart Collections: sync failed, see log")
	end
end

function Scheduler.statusText()
	local parts = {}
	parts[#parts + 1] = S.running and "Background sync running" or "Background sync stopped"
	if S.busy then parts[#parts + 1] = "(syncing now)" end
	if S.lastRunAt then
		parts[#parts + 1] = "· last run " .. LrDate.timeToUserFormat(S.lastRunAt, "%H:%M:%S")
	end
	if S.lastResult then
		parts[#parts + 1] = ("· %d mirror(s)"):format(S.lastResult.mirrors)
	end
	if S.lastError then parts[#parts + 1] = "· last error: " .. S.lastError end
	if S.lastSkip then parts[#parts + 1] = "· last check skipped (" .. S.lastSkip .. ")" end
	return table.concat(parts, " ")
end

return Scheduler
