local t = require "t"
local stub = require "lr_stub"
local SyncEngine = require "SyncEngine"
local Prefs = require "Prefs"

local cat = stub.catalog
stub.prefs.notifyStyle = "dialog"

local function mirrorSet()
	for _, s in ipairs(cat:getChildCollectionSets()) do
		if s:getName() == Prefs.MIRROR_SET_NAME then return s end
	end
end
local function mirrorNamed(name)
	for _, c in ipairs(mirrorSet():getChildCollections()) do if c:getName() == name then return c end end
end
local function count(c) return #c:getPhotos() end

-- 1. three smart collections, one nested -> mirrors created with matching photos + one dialog
local year = cat:addSet("2024")
local a = cat:addSmart("Five Stars", nil, stub.photos(1, 10))
local b = cat:addSmart("Keepers", nil, stub.photos(5, 20))
local c = cat:addSmart("Keepers", year, stub.photos(100, 102))
local r = SyncEngine.runCycle("test")
t.eq(#r.created, 3, "three mirrors created")
t.ok(mirrorSet() ~= nil, "mirror set exists")
t.eq(#mirrorSet():getChildCollections(), 3, "mirror set has three children")
t.eq(count(mirrorNamed("Five Stars")), 10, "Five Stars synced")
t.eq(count(mirrorNamed("Keepers")), 16, "Keepers synced")
t.eq(count(mirrorNamed("Keepers (2024)")), 3, "nested Keepers gets parent suffix")
t.eq(#stub.dialogs, 1, "one notification dialog")
t.ok(cat._props.mapping ~= nil, "mapping persisted")

-- 2. steady state: no undo entries, no dialog
local undoBefore = #cat._undo
r = SyncEngine.runCycle("test")
t.eq(#cat._undo, undoBefore, "no write block when nothing changed")
t.eq(r.changed, 0, "no changes")
t.eq(#stub.dialogs, 1, "no extra dialog")

-- 3. rule change -> delta applied, exactly one write block
a._photos = stub.photos(3, 12)
undoBefore = #cat._undo
r = SyncEngine.runCycle("test")
t.eq(count(mirrorNamed("Five Stars")), 10, "membership updated")
t.eq(#cat._undo, undoBefore + 1, "one undo entry for photo sync")
local ids = {}
for _, p in ipairs(mirrorNamed("Five Stars"):getPhotos()) do ids[#ids + 1] = p.localIdentifier end
table.sort(ids)
t.eq(ids, { 3, 4, 5, 6, 7, 8, 9, 10, 11, 12 }, "exact membership")

-- 4. rename follows source
a:setName("Best")
SyncEngine.runCycle("test")
t.ok(mirrorNamed("Best") ~= nil and mirrorNamed("Five Stars") == nil, "mirror renamed")

-- 5. delete source -> mirror deleted
cat:deleteObject(c)
SyncEngine.runCycle("test")
t.eq(#mirrorSet():getChildCollections(), 2, "mirror deleted with source")
t.ok(mirrorNamed("Keepers (2024)") == nil, "nested mirror gone")

-- 6. user deletes a mirror -> recreated + notified
cat:deleteObject(mirrorNamed("Best"))
r = SyncEngine.runCycle("test")
t.eq(r.created, { "Best" }, "mirror recreated")
t.eq(count(mirrorNamed("Best")), 10, "recreated mirror filled")
t.eq(#stub.dialogs, 2, "notified about recreation")

-- 7. user deletes the whole mirror set -> set + mirrors recreated, no duplicates
cat:deleteObject(mirrorSet())
SyncEngine.runCycle("test")
t.eq(#cat:getChildCollectionSets(), 2, "exactly one mirror set plus the year set")
t.eq(#mirrorSet():getChildCollections(), 2, "both mirrors recreated")

-- 8. mapping lost (e.g. catalog property cleared) -> adopt by name, no duplicates
cat._props.mapping = nil
r = SyncEngine.runCycle("test")
t.eq(#r.created, 0, "adopted, nothing created")
t.eq(#mirrorSet():getChildCollections(), 2, "still two mirrors")

-- 9. smart collection inside the mirror set is ignored
cat:addSmart("Inside", mirrorSet(), stub.photos(1, 2))
r = SyncEngine.runCycle("test")
t.eq(#r.created, 0, "no mirror for smart collection in mirror set")

-- 10. photos added by hand to a mirror are removed
local best = mirrorNamed("Best")
best._photos[#best._photos + 1] = { localIdentifier = 999 }
SyncEngine.runCycle("test")
t.eq(count(best), 10, "manual additions removed")

-- 11. catalog busy -> no crash, retried next cycle
a._photos = stub.photos(1, 3)
stub.writeStatus = "aborted"
r = SyncEngine.runCycle("test")
t.eq(r.errors, 1, "busy reported as error")
t.eq(count(best), 10, "nothing changed while busy")
stub.writeStatus = "executed"
r = SyncEngine.runCycle("test")
t.eq(count(best), 3, "applied after catalog free")

-- 12. large collection chunks across several write blocks
local big = cat:addSmart("Big", nil, stub.photos(10000, 15000))
undoBefore = #cat._undo
SyncEngine.runCycle("test")
t.eq(count(mirrorNamed("Big")), 5001, "large collection fully mirrored")
t.ok(#cat._undo - undoBefore >= 3, "split into multiple write blocks (structure + >=2 photo blocks)")

t.report("test_sync_engine")
