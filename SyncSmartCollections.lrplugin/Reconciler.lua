-- Reconciler.lua - pure planning logic. Given a snapshot of the catalog and the
-- persisted smart->mirror mapping, decide which structural actions to take.
-- No Lightroom imports: operates on plain tables so it can be unit-tested.
--
-- input = {
--   smarts            = { { id, name, parentName, inMirrorSet } },   -- every smart collection found
--   mapping           = { [smartId] = mirrorId },
--   mirrorsById       = { [mirrorId] = { name = ... } },             -- mirrors that still resolve
--   mirrorSetChildren = { { id, name, isSmart } },                   -- direct children of the mirror set
-- }
-- output = { actions = { ... }, mapping = { [smartId] = mirrorId }, warnings = { ... } }
--
-- Action shapes (in emission order):
--   { type = "delete", mirrorId, reason }   { type = "unmap",  smartId }
--   { type = "adopt",  smartId, mirrorId }  { type = "create", smartId, name }
--   { type = "rename", mirrorId, name }
-- "create" actions are not in the returned mapping; the caller fills in the new id.

local Reconciler = {}

local function sortById(list)
	local out = {}
	for _, item in ipairs(list) do out[#out + 1] = item end
	table.sort(out, function(a, b) return a.id < b.id end)
	return out
end

local function pickName(base, parentName, claimed)
	if not claimed[base] then return base end
	if parentName and parentName ~= "" then
		local withParent = base .. " (" .. parentName .. ")"
		if not claimed[withParent] then return withParent end
	end
	local n = 2
	while true do
		local candidate = base .. " (" .. n .. ")"
		if not claimed[candidate] then return candidate end
		n = n + 1
	end
end

function Reconciler.plan(input)
	local actions, warnings = {}, {}
	local mapping = {}
	for k, v in pairs(input.mapping or {}) do mapping[k] = v end
	local mirrorsById = input.mirrorsById or {}

	-- 1. Partition smart collections; those inside the mirror set are ignored.
	local active, activeById = {}, {}
	for _, s in ipairs(input.smarts or {}) do
		if s.inMirrorSet then
			warnings[#warnings + 1] = ("Smart collection '%s' lives inside the mirror set and is ignored"):format(s.name)
		else
			active[#active + 1] = s
			activeById[s.id] = s
		end
	end
	active = sortById(active)

	-- 2/3. Stale mappings and mappings whose mirror is gone.
	local staleIds = {}
	for smartId in pairs(mapping) do staleIds[#staleIds + 1] = smartId end
	table.sort(staleIds)
	for _, smartId in ipairs(staleIds) do
		local mirrorId = mapping[smartId]
		if not activeById[smartId] then
			if mirrorsById[mirrorId] then
				actions[#actions + 1] = { type = "delete", mirrorId = mirrorId, reason = "source deleted" }
			end
			actions[#actions + 1] = { type = "unmap", smartId = smartId }
			mapping[smartId] = nil
		elseif not mirrorsById[mirrorId] then
			actions[#actions + 1] = { type = "unmap", smartId = smartId }
			mapping[smartId] = nil
		end
	end

	-- 4. Unreferenced regular collections in the mirror set: adoptable by exact name,
	--    and their names are claimed so we never create a duplicate.
	local referenced = {}
	for _, mirrorId in pairs(mapping) do referenced[mirrorId] = true end
	local claimed, adoptable = {}, {}
	for _, c in ipairs(input.mirrorSetChildren or {}) do
		if not c.isSmart and not referenced[c.id] then
			claimed[c.name] = true
			if not adoptable[c.name] then adoptable[c.name] = c.id end
		end
	end

	-- 5-7. Walk smart collections oldest first; assign names, adopt, create, rename.
	local adopts, creates, renames = {}, {}, {}
	for _, s in ipairs(active) do
		local mirrorId = mapping[s.id]
		if mirrorId then
			local desired = pickName(s.name, s.parentName, claimed)
			claimed[desired] = true
			if mirrorsById[mirrorId].name ~= desired then
				renames[#renames + 1] = { type = "rename", mirrorId = mirrorId, name = desired }
			end
		elseif adoptable[s.name] and not referenced[adoptable[s.name]] then
			local id = adoptable[s.name]
			adoptable[s.name] = nil
			referenced[id] = true
			mapping[s.id] = id
			adopts[#adopts + 1] = { type = "adopt", smartId = s.id, mirrorId = id }
		else
			local desired = pickName(s.name, s.parentName, claimed)
			claimed[desired] = true
			creates[#creates + 1] = { type = "create", smartId = s.id, name = desired }
		end
	end

	for _, a in ipairs(adopts) do actions[#actions + 1] = a end
	for _, a in ipairs(creates) do actions[#actions + 1] = a end
	for _, a in ipairs(renames) do actions[#actions + 1] = a end

	return { actions = actions, mapping = mapping, warnings = warnings }
end

return Reconciler
