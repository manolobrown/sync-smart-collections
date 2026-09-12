-- InitPlugin.lua - runs when the plug-in loads (LrForceInitPlugin makes this happen at launch).

local LrApplication = import "LrApplication"

local Prefs = require "Prefs"
local Log = require "Log"
local Scheduler = require "Scheduler"

local prefs = Prefs.get()
Log.setVerbose(prefs.verboseLogging)
Log.info("Sync Smart Collections loading in Lightroom %s", LrApplication.versionString())
Scheduler.start()
