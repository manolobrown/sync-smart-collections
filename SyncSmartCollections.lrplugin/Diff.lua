-- Diff.lua - pure id-set diff. No Lightroom imports; runs under plain Lua too.

local Diff = {}

local function toSet(list)
	local set = {}
	for _, id in ipairs(list) do set[id] = true end
	return set
end

local function sortedKeys(set)
	local out = {}
	for id in pairs(set) do out[#out + 1] = id end
	table.sort(out, function(a, b) return tostring(a) < tostring(b) end)
	return out
end

-- Returns (toAdd, toRemove): ids present in source but not mirror, and vice versa.
-- Both results are sorted arrays so cycles are deterministic and easy to log.
function Diff.compute(sourceIds, mirrorIds)
	local source, mirror = toSet(sourceIds), toSet(mirrorIds)
	local add, remove = {}, {}
	for id in pairs(source) do
		if not mirror[id] then add[id] = true end
	end
	for id in pairs(mirror) do
		if not source[id] then remove[id] = true end
	end
	return sortedKeys(add), sortedKeys(remove)
end

return Diff
