local t = require "t"
local R = require "Reconciler"

local function smart(id, name, parentName, inMirrorSet)
	return { id = id, name = name, parentName = parentName, inMirrorSet = inMirrorSet or false }
end
local function child(id, name, isSmart)
	return { id = id, name = name, isSmart = isSmart or false }
end
local function plan(input)
	input.smarts = input.smarts or {}
	input.mapping = input.mapping or {}
	input.mirrorsById = input.mirrorsById or {}
	input.mirrorSetChildren = input.mirrorSetChildren or {}
	return R.plan(input)
end
local function types(actions)
	local out = {}
	for _, a in ipairs(actions) do out[#out + 1] = a.type end
	return out
end

-- new smart -> create
local r = plan { smarts = { smart(10, "Keepers") } }
t.eq(r.actions, { { type = "create", smartId = 10, name = "Keepers" } }, "new smart creates")
t.eq(r.mapping, {}, "create not yet mapped")

-- mapped + present + name matches -> nothing
r = plan { smarts = { smart(10, "Keepers") }, mapping = { [10] = 20 }, mirrorsById = { [20] = { name = "Keepers" } },
	mirrorSetChildren = { child(20, "Keepers") } }
t.eq(r.actions, {}, "steady state no actions")
t.eq(r.mapping, { [10] = 20 }, "steady state mapping kept")

-- smart deleted -> delete mirror + unmap
r = plan { mapping = { [10] = 20 }, mirrorsById = { [20] = { name = "Keepers" } }, mirrorSetChildren = { child(20, "Keepers") } }
t.eq(r.actions, { { type = "delete", mirrorId = 20, reason = "source deleted" }, { type = "unmap", smartId = 10 } }, "deleted smart")
t.eq(r.mapping, {}, "deleted smart unmapped")

-- smart deleted and mirror already gone -> just unmap
r = plan { mapping = { [10] = 20 } }
t.eq(r.actions, { { type = "unmap", smartId = 10 } }, "deleted smart, missing mirror")

-- mirror missing (user deleted it) -> unmap + create
r = plan { smarts = { smart(10, "Keepers") }, mapping = { [10] = 20 } }
t.eq(r.actions, { { type = "unmap", smartId = 10 }, { type = "create", smartId = 10, name = "Keepers" } }, "missing mirror recreated")

-- adopt by name when mapping lost
r = plan { smarts = { smart(10, "Keepers") }, mirrorSetChildren = { child(99, "Keepers") } }
t.eq(r.actions, { { type = "adopt", smartId = 10, mirrorId = 99 } }, "adopt orphan by name")
t.eq(r.mapping, { [10] = 99 }, "adopted mapping")

-- do not adopt a smart collection living in the mirror set; do not adopt a referenced mirror
r = plan { smarts = { smart(10, "Keepers"), smart(11, "Keepers") }, mapping = { [10] = 99 },
	mirrorsById = { [99] = { name = "Keepers" } }, mirrorSetChildren = { child(99, "Keepers"), child(50, "Keepers", true) } }
t.eq(r.actions, { { type = "create", smartId = 11, name = "Keepers (2)" } }, "no adopt of referenced/smart; collision suffix")

-- rename follows source
r = plan { smarts = { smart(10, "Picks") }, mapping = { [10] = 20 }, mirrorsById = { [20] = { name = "Keepers" } },
	mirrorSetChildren = { child(20, "Keepers") } }
t.eq(r.actions, { { type = "rename", mirrorId = 20, name = "Picks" } }, "rename")

-- collision across sets -> parent set suffix; older id keeps plain name
r = plan { smarts = { smart(12, "Keepers", "2024"), smart(11, "Keepers", "2023") } }
t.eq(r.actions, { { type = "create", smartId = 11, name = "Keepers" }, { type = "create", smartId = 12, name = "Keepers (2024)" } }, "parent suffix")

-- triple collision -> numeric suffix once parent suffix is taken too
r = plan { smarts = { smart(11, "Keepers", "A"), smart(12, "Keepers", "A"), smart(13, "Keepers", "A") } }
t.eq(r.actions, {
	{ type = "create", smartId = 11, name = "Keepers" },
	{ type = "create", smartId = 12, name = "Keepers (A)" },
	{ type = "create", smartId = 13, name = "Keepers (2)" },
}, "numeric suffix")

-- unmanaged regular collection in mirror set with a clashing name is never deleted, name counts as claimed
r = plan { smarts = { smart(11, "Keepers", "A"), smart(12, "Keepers", "A") }, mirrorSetChildren = { child(70, "Keepers (A)") } }
t.eq(r.actions, {
	{ type = "create", smartId = 11, name = "Keepers" },
	{ type = "create", smartId = 12, name = "Keepers (2)" },
}, "unmanaged name claimed; exact-name adopt only")

-- smart collection inside the mirror set is ignored with a warning
r = plan { smarts = { smart(10, "Inside", nil, true) } }
t.eq(r.actions, {}, "ignored smart in mirror set")
t.eq(#r.warnings, 1, "warning emitted")

t.report("test_reconciler")
