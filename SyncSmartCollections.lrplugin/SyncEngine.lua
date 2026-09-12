-- SyncEngine.lua - runs one sync cycle: reconcile mirror structure, then photo membership.
-- Every catalog write in the plug-in happens here or in MirrorRegistry.

local LrApplication = import "LrApplication"
local LrTasks = import "LrTasks"
local LrDate = import "LrDate"

local CatalogWalker = require "CatalogWalker"
local MirrorRegistry = require "MirrorRegistry"
local Reconciler = require "Reconciler"
local Diff = require "Diff"
local Notifier = require "Notifier"
local Log = require "Log"

local SyncEngine = {}

local PHOTOS_PER_CALL = 500      -- max photos per addPhotos/removePhotos call
local OPS_PER_WRITE_BLOCK = 2000 -- max photo operations per withWriteAccessDo
local WRITE_TIMEOUT = 15

local function ids(photos)
	local list, byId = {}, {}
	for _, p in ipairs(photos) do
		local id = p.localIdentifier
		list[#list + 1] = id
		byId[id] = p
	end
	return list, byId
end

local function chunked(list, size)
	local chunks, i = {}, 1
	while i <= #list do
		local chunk = {}
		for j = i, math.min(i + size - 1, #list) do chunk[#chunk + 1] = list[j] end
		chunks[#chunks + 1] = chunk
		i = i + size
	end
	return chunks
end

-- Applies structural actions in a single write block. Returns (status, createdNames, pendingById).
local function applyStructure(catalog, mirrorSet, plan, mirrorsById)
	local created, pending = {}, {}
	local status = catalog:withWriteAccessDo("Sync Smart Collections: update mirrors", function()
		for _, a in ipairs(plan.actions) do
			if a.type == "delete" then
				local m = mirrorsById[a.mirrorId]
				if m then
					Log.info("deleting mirror '%s' (%s)", m.name, a.reason or "")
					m.collection:delete()
				end
			elseif a.type == "create" then
				Log.info("creating mirror '%s'", a.name)
				local c = catalog:createCollection(a.name, mirrorSet, true)
				pending[a.smartId] = c
				created[#created + 1] = a.name
			elseif a.type == "rename" then
				local m = mirrorsById[a.mirrorId]
				if m then
					Log.info("renaming mirror '%s' -> '%s'", m.name, a.name)
					m.collection:setName(a.name)
				end
			elseif a.type == "adopt" then
				Log.info("adopting existing collection %s for smart collection %s", tostring(a.mirrorId), tostring(a.smartId))
			elseif a.type == "unmap" then
				Log.trace("unmapping smart collection %s", tostring(a.smartId))
			end
		end
	end, { timeout = WRITE_TIMEOUT })
	return status, created, pending
end

-- Computes the photo delta for every mapped pair. Returns a list of { mirror, name, add = {photos}, remove = {photos} }.
local function planMembership(catalog, smarts, mapping, mirrorsById, pending)
	local ops = {}
	for _, s in ipairs(smarts) do
		if not s.inMirrorSet and mapping[s.id] then
			local mirror = pending[s.id] or (mirrorsById[mapping[s.id]] and mirrorsById[mapping[s.id]].collection)
				or catalog:getCollectionByLocalIdentifier(mapping[s.id])
			if mirror then
				local srcIds, srcById = ids(s.collection:getPhotos())
				local dstIds, dstById = ids(mirror:getPhotos())
				local toAdd, toRemove = Diff.compute(srcIds, dstIds)
				if #toAdd > 0 or #toRemove > 0 then
					local add, remove = {}, {}
					for _, id in ipairs(toAdd) do add[#add + 1] = srcById[id] end
					for _, id in ipairs(toRemove) do remove[#remove + 1] = dstById[id] end
					Log.trace("'%s': +%d -%d", s.name, #add, #remove)
					-- Split oversized deltas so no single write block holds the UI for too long.
					for _, chunk in ipairs(chunked(remove, OPS_PER_WRITE_BLOCK)) do
						ops[#ops + 1] = { mirror = mirror, name = s.name, add = {}, remove = chunk }
					end
					for _, chunk in ipairs(chunked(add, OPS_PER_WRITE_BLOCK)) do
						ops[#ops + 1] = { mirror = mirror, name = s.name, add = chunk, remove = {} }
					end
				end
				LrTasks.yield()
			end
		end
	end
	return ops
end

-- Executes membership ops in write blocks capped at OPS_PER_WRITE_BLOCK photo operations.
local function applyMembership(catalog, ops)
	local changed, errors = 0, 0
	local batch, batchSize = {}, 0

	local function flush()
		if #batch == 0 then return end
		local status = catalog:withWriteAccessDo("Sync Smart Collections: sync photos", function()
			for _, op in ipairs(batch) do
				for _, chunk in ipairs(chunked(op.remove, PHOTOS_PER_CALL)) do op.mirror:removePhotos(chunk) end
				for _, chunk in ipairs(chunked(op.add, PHOTOS_PER_CALL)) do op.mirror:addPhotos(chunk) end
			end
		end, { timeout = WRITE_TIMEOUT })
		if status == "executed" then
			for _, op in ipairs(batch) do
				changed = changed + 1
				Log.info("synced '%s': +%d -%d", op.name, #op.add, #op.remove)
			end
		else
			errors = errors + 1
			Log.warn("write access not granted (%s); %d mirror(s) will retry next cycle", tostring(status), #batch)
		end
		batch, batchSize = {}, 0
		LrTasks.yield()
	end

	for _, op in ipairs(ops) do
		local size = #op.add + #op.remove
		if batchSize > 0 and batchSize + size > OPS_PER_WRITE_BLOCK then flush() end
		batch[#batch + 1] = op
		batchSize = batchSize + size
		if batchSize >= OPS_PER_WRITE_BLOCK then flush() end
	end
	flush()
	return changed, errors
end

-- Runs a full cycle. Returns { created = {names}, mirrors = n, changed = n, errors = n, durationSeconds = s }.
function SyncEngine.runCycle(reason)
	local started = LrDate.currentTime()
	local catalog = LrApplication.activeCatalog()
	Log.trace("cycle start (%s)", tostring(reason))

	local mirrorSet = MirrorRegistry.ensureMirrorSet(catalog)
	local snap = CatalogWalker.snapshot(catalog, mirrorSet)
	local mapping = MirrorRegistry.load(catalog)
	local mirrorsById = MirrorRegistry.resolveMirrors(catalog, mapping)

	local plan = Reconciler.plan {
		smarts = snap.smarts,
		mapping = mapping,
		mirrorsById = mirrorsById,
		mirrorSetChildren = snap.mirrorSetChildren,
	}
	for _, w in ipairs(plan.warnings) do Log.warn("%s", w) end

	local created, pending = {}, {}
	if #plan.actions > 0 then
		local status
		status, created, pending = applyStructure(catalog, mirrorSet, plan, mirrorsById)
		if status ~= "executed" then
			Log.warn("could not update mirror structure (%s); will retry next cycle", tostring(status))
			return { created = {}, mirrors = 0, changed = 0, errors = 1, durationSeconds = LrDate.currentTime() - started }
		end
		for smartId, c in pairs(pending) do plan.mapping[smartId] = c.localIdentifier end
	end
	MirrorRegistry.save(catalog, plan.mapping)

	local ops = planMembership(catalog, snap.smarts, plan.mapping, mirrorsById, pending)
	local changed, errors = applyMembership(catalog, ops)

	local mirrors = 0
	for _ in pairs(plan.mapping) do mirrors = mirrors + 1 end
	local result = { created = created, mirrors = mirrors, changed = changed, errors = errors,
		durationSeconds = LrDate.currentTime() - started }
	Log.info("cycle done (%s): %d mirror(s), %d created, %d updated, %d error(s), %.1fs",
		tostring(reason), mirrors, #created, changed, errors, result.durationSeconds)

	if #created > 0 then Notifier.mirrorsCreated(created) end
	return result
end

return SyncEngine
