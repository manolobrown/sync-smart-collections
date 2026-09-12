-- CatalogWalker.lua - builds a plain-table snapshot of every smart collection in the catalog
-- plus the direct children of the mirror set. Must be called from an async task.

local LrTasks = import "LrTasks"

local CatalogWalker = {}

local YIELD_EVERY = 25

-- Returns { smarts = { {id, name, parentName, inMirrorSet, collection} },
--           mirrorSetChildren = { {id, name, isSmart, collection} } }
function CatalogWalker.snapshot(catalog, mirrorSet)
	local mirrorSetId = mirrorSet and mirrorSet.localIdentifier or nil
	local out = { smarts = {}, mirrorSetChildren = {} }
	local visited = 0

	local function tick()
		visited = visited + 1
		if visited % YIELD_EVERY == 0 then LrTasks.yield() end
	end

	local function walk(container, parentName, inMirrorSet, isMirrorSetItself)
		for _, c in ipairs(container:getChildCollections()) do
			tick()
			local isSmart = c:isSmartCollection()
			if isSmart then
				out.smarts[#out.smarts + 1] = {
					id = c.localIdentifier,
					name = c:getName(),
					parentName = parentName,
					inMirrorSet = inMirrorSet,
					collection = c,
				}
			end
			if isMirrorSetItself then
				out.mirrorSetChildren[#out.mirrorSetChildren + 1] = {
					id = c.localIdentifier,
					name = c:getName(),
					isSmart = isSmart,
					collection = c,
				}
			end
		end
		for _, set in ipairs(container:getChildCollectionSets()) do
			tick()
			local isMirror = mirrorSetId ~= nil and set.localIdentifier == mirrorSetId
			walk(set, set:getName(), inMirrorSet or isMirror, isMirror)
		end
	end

	walk(catalog, nil, false, false)
	return out
end

return CatalogWalker
