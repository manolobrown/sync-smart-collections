-- lr_stub.lua - minimal fake of the Lightroom SDK so SyncEngine / Scheduler / MirrorRegistry
-- can be exercised outside Lightroom. Only what the plug-in uses is modelled.

local stub = {}
local nextId = 1000
local function newId() nextId = nextId + 1 return nextId end

stub.log = {}
stub.dialogs = {}
stub.bezels = {}
stub.module = "library"
stub.writeStatus = "executed"
stub.now = 0

_PLUGIN = { id = "test" }

-- ---- fake catalog objects -------------------------------------------------
local Collection = {}
Collection.__index = Collection
function Collection:type() return "LrCollection" end
function Collection:isSmartCollection() return self._smart end
function Collection:getName() return self._name end
function Collection:setName(n) self._name = n end
function Collection:getParent() return self._parent end
function Collection:getPhotos()
	local out = {}
	for _, p in ipairs(self._photos) do out[#out + 1] = p end
	return out
end
function Collection:addPhotos(photos)
	assert(not self._smart, "addPhotos on smart collection")
	assert(self._catalog._writing, "addPhotos outside write access")
	local have = {}
	for _, p in ipairs(self._photos) do have[p.localIdentifier] = true end
	for _, p in ipairs(photos) do
		if not have[p.localIdentifier] then self._photos[#self._photos + 1] = p; have[p.localIdentifier] = true end
	end
end
function Collection:removePhotos(photos)
	assert(not self._smart, "removePhotos on smart collection")
	assert(self._catalog._writing, "removePhotos outside write access")
	local drop = {}
	for _, p in ipairs(photos) do drop[p.localIdentifier] = true end
	local keep = {}
	for _, p in ipairs(self._photos) do if not drop[p.localIdentifier] then keep[#keep + 1] = p end end
	self._photos = keep
end
function Collection:delete()
	assert(self._catalog._writing, "delete outside write access")
	self._parent:_removeChild(self)
	self._catalog._byId[self.localIdentifier] = nil
end

local Set = {}
Set.__index = Set
function Set:type() return "LrCollectionSet" end
function Set:getName() return self._name end
function Set:setName(n) self._name = n end
function Set:getParent() return self._parent end
function Set:getChildCollections() local o = {} for _, c in ipairs(self._collections) do o[#o + 1] = c end return o end
function Set:getChildCollectionSets() local o = {} for _, c in ipairs(self._sets) do o[#o + 1] = c end return o end
function Set:_removeChild(child)
	for i, c in ipairs(self._collections) do if c == child then table.remove(self._collections, i) return end end
	for i, c in ipairs(self._sets) do if c == child then table.remove(self._sets, i) return end end
end
function Set:delete()
	assert(self._catalog._writing, "delete outside write access")
	for _, c in ipairs(self:getChildCollections()) do c:delete() end
	for _, c in ipairs(self:getChildCollectionSets()) do c:delete() end
	self._parent:_removeChild(self)
	self._catalog._byId[self.localIdentifier] = nil
end

local Catalog = {}
Catalog.__index = Catalog

function stub.newCatalog()
	local cat = setmetatable({ _byId = {}, _props = {}, _writing = false, _undo = {}, _collections = {}, _sets = {} }, Catalog)
	return cat
end
function Catalog:getChildCollections() return Set.getChildCollections(self) end
function Catalog:getChildCollectionSets() return Set.getChildCollectionSets(self) end
function Catalog:_removeChild(c) Set._removeChild(self, c) end
function Catalog:getCollectionByLocalIdentifier(id) return self._byId[id] end
function Catalog:getPropertyForPlugin(_, key) return self._props[key] end
function Catalog:setPropertyForPlugin(_, key, value)
	assert(self._writing or self._privateWriting, "setPropertyForPlugin outside write access")
	self._props[key] = value
end
function Catalog:withWriteAccessDo(name, fn, opts)
	if stub.writeStatus ~= "executed" then return stub.writeStatus end
	self._undo[#self._undo + 1] = name
	self._writing = true
	local ok, err = pcall(fn)
	self._writing = false
	if not ok then error(err, 0) end
	return "executed"
end
function Catalog:withPrivateWriteAccessDo(fn, opts)
	self._privateWriting = true
	local ok, err = pcall(fn)
	self._privateWriting = false
	if not ok then error(err, 0) end
	return "executed"
end
function Catalog:createCollection(name, parent, canReturnExisting)
	assert(self._writing, "createCollection outside write access")
	parent = parent or self
	for _, c in ipairs(parent._collections) do
		if c._name == name then
			if canReturnExisting then return c end
			error("collection exists: " .. name)
		end
	end
	local c = setmetatable({ localIdentifier = newId(), _name = name, _smart = false, _photos = {}, _parent = parent, _catalog = self }, Collection)
	parent._collections[#parent._collections + 1] = c
	self._byId[c.localIdentifier] = c
	return c
end
function Catalog:createCollectionSet(name, parent, canReturnExisting)
	assert(self._writing, "createCollectionSet outside write access")
	parent = parent or self
	for _, s in ipairs(parent._sets) do
		if s._name == name then
			if canReturnExisting then return s end
			error("set exists: " .. name)
		end
	end
	local s = setmetatable({ localIdentifier = newId(), _name = name, _parent = parent, _catalog = self, _collections = {}, _sets = {} }, Set)
	parent._sets[#parent._sets + 1] = s
	self._byId[s.localIdentifier] = s
	return s
end
-- test helpers (bypass write access)
function Catalog:addSmart(name, parent, photos)
	self._writing = true
	local c = self:createCollection(name, parent, false)
	self._writing = false
	c._smart = true
	c._photos = photos or {}
	return c
end
function Catalog:addSet(name, parent)
	self._writing = true
	local s = self:createCollectionSet(name, parent, false)
	self._writing = false
	return s
end
function Catalog:addRegular(name, parent, photos)
	self._writing = true
	local c = self:createCollection(name, parent, false)
	self._writing = false
	c._photos = photos or {}
	return c
end
function Catalog:deleteObject(obj)
	self._writing = true
	obj:delete()
	self._writing = false
end
function stub.photos(from, to)
	local out = {}
	for i = from, to do out[#out + 1] = { localIdentifier = i } end
	return out
end

-- ---- import() ---------------------------------------------------------------
stub.catalog = stub.newCatalog()
stub.prefs = {}

local modules = {}
modules.LrTasks = {
	startAsyncTask = function(fn) fn() end,
	sleep = function() end,
	yield = function() end,
	pcall = pcall,
	canYield = function() return true end,
}
modules.LrApplication = {
	activeCatalog = function() return stub.catalog end,
	versionString = function() return "stub" end,
}
modules.LrApplicationView = { getCurrentModuleName = function() return stub.module end }
modules.LrDate = {
	currentTime = function() stub.now = stub.now + 0.01 return stub.now end,
	timeToUserFormat = function(t) return tostring(t) end,
}
modules.LrDialogs = {
	message = function(a, b) stub.dialogs[#stub.dialogs + 1] = { a, b } end,
	showBezel = function(m) stub.bezels[#stub.bezels + 1] = m end,
}
modules.LrLogger = function(name)
	local l = {}
	function l:enable() end
	for _, level in ipairs { "info", "warn", "error", "trace" } do
		l[level] = function(_, msg) stub.log[#stub.log + 1] = level .. ": " .. msg end
	end
	return l
end
modules.LrPathUtils = {
	getStandardFilePath = function() return "/tmp" end,
	child = function(a, b) return a .. "/" .. b end,
}
modules.LrPrefs = { prefsForPlugin = function() return stub.prefs end }
modules.LrShell = { revealInFinder = function() end }
modules.LrFileUtils = { exists = function() return false end }
modules.LrView = { bind = function(k) return k end }

function import(name)
	return assert(modules[name], "stub has no module " .. name)
end

return stub
