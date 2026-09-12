-- MirrorRegistry.lua - persists the smart->mirror mapping in the catalog and owns the mirror set.

local MappingCodec = require "MappingCodec"
local Prefs = require "Prefs"
local Log = require "Log"

local MirrorRegistry = {}

local KEY_MAPPING = "mapping"
local KEY_MIRROR_SET = "mirrorSetId"

function MirrorRegistry.load(catalog)
	local raw = catalog:getPropertyForPlugin(_PLUGIN, KEY_MAPPING)
	local mapping = MappingCodec.decode(raw)
	local n = 0
	for _ in pairs(mapping) do n = n + 1 end
	Log.trace("loaded %d mapping(s)", n)
	return mapping
end

-- Writes the mapping only when it changed. Uses private write access so no undo entry is created.
function MirrorRegistry.save(catalog, mapping)
	local encoded = MappingCodec.encode(mapping)
	if catalog:getPropertyForPlugin(_PLUGIN, KEY_MAPPING) == encoded then return end
	catalog:withPrivateWriteAccessDo(function()
		catalog:setPropertyForPlugin(_PLUGIN, KEY_MAPPING, encoded)
	end, { timeout = 10 })
	Log.trace("saved mapping: %s", encoded)
end

local function isCollectionSet(obj)
	return obj ~= nil and type(obj.type) == "function" and obj:type() == "LrCollectionSet"
end

-- Finds the mirror set by stored id (survives a user rename), then by name, else creates it.
function MirrorRegistry.ensureMirrorSet(catalog)
	local storedId = catalog:getPropertyForPlugin(_PLUGIN, KEY_MIRROR_SET)
	if storedId then
		local set = catalog:getCollectionByLocalIdentifier(storedId)
		if isCollectionSet(set) then return set end
		Log.warn("stored mirror set %s no longer exists; recreating", tostring(storedId))
	end

	local set
	for _, s in ipairs(catalog:getChildCollectionSets()) do
		if s:getName() == Prefs.MIRROR_SET_NAME then set = s break end
	end

	if not set then
		local status = catalog:withWriteAccessDo("Sync Smart Collections: create mirror set", function()
			set = catalog:createCollectionSet(Prefs.MIRROR_SET_NAME, nil, true)
		end, { timeout = 10 })
		if status ~= "executed" or not set then
			error("could not create mirror set (catalog busy: " .. tostring(status) .. ")")
		end
		Log.info("created mirror set '%s'", Prefs.MIRROR_SET_NAME)
	end

	catalog:withPrivateWriteAccessDo(function()
		catalog:setPropertyForPlugin(_PLUGIN, KEY_MIRROR_SET, set.localIdentifier)
	end, { timeout = 10 })
	return set
end

-- Returns { [mirrorId] = { name = ..., collection = ... } } for mirrors that still exist.
function MirrorRegistry.resolveMirrors(catalog, mapping)
	local out = {}
	for _, mirrorId in pairs(mapping) do
		local c = catalog:getCollectionByLocalIdentifier(mirrorId)
		if c and type(c.type) == "function" and c:type() == "LrCollection" and not c:isSmartCollection() then
			out[mirrorId] = { name = c:getName(), collection = c }
		end
	end
	return out
end

return MirrorRegistry
