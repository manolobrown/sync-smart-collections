-- Log.lua - thin wrapper around LrLogger writing to ~/Documents/LrClassicLogs/SyncSmartCollections.log

local LrLogger = import "LrLogger"
local LrPathUtils = import "LrPathUtils"

local logger = LrLogger("SyncSmartCollections")
logger:enable("logfile")

local Log = {}

local verbose = false

function Log.setVerbose(flag)
	verbose = flag and true or false
end

local function fmt(s, ...)
	if select("#", ...) > 0 then
		local ok, out = pcall(string.format, s, ...)
		if ok then return out end
		return tostring(s)
	end
	return tostring(s)
end

function Log.info(s, ...)  logger:info(fmt(s, ...)) end
function Log.warn(s, ...)  logger:warn(fmt(s, ...)) end
function Log.error(s, ...) logger:error(fmt(s, ...)) end
function Log.trace(s, ...)
	if verbose then logger:trace(fmt(s, ...)) end
end

function Log.path()
	local docs = LrPathUtils.getStandardFilePath("documents")
	return LrPathUtils.child(LrPathUtils.child(docs, "LrClassicLogs"), "SyncSmartCollections.log")
end

return Log
