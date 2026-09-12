-- Minimal test helper (no dependencies).
local t = { failures = 0, passes = 0 }

local function dump(v, depth)
	depth = depth or 0
	if type(v) ~= "table" then return tostring(v) end
	if depth > 4 then return "{...}" end
	local keys = {}
	for k in pairs(v) do keys[#keys + 1] = k end
	table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
	local parts = {}
	for _, k in ipairs(keys) do
		parts[#parts + 1] = tostring(k) .. "=" .. dump(v[k], depth + 1)
	end
	return "{" .. table.concat(parts, ", ") .. "}"
end
t.dump = dump

local function deepEq(a, b)
	if type(a) ~= type(b) then return false end
	if type(a) ~= "table" then return a == b end
	for k, v in pairs(a) do
		if not deepEq(v, b[k]) then return false end
	end
	for k in pairs(b) do
		if a[k] == nil then return false end
	end
	return true
end
t.deepEq = deepEq

function t.eq(actual, expected, label)
	if deepEq(actual, expected) then
		t.passes = t.passes + 1
	else
		t.failures = t.failures + 1
		print(("FAIL %s\n  expected: %s\n  actual:   %s"):format(label or "?", dump(expected), dump(actual)))
	end
end

function t.ok(cond, label)
	t.eq(cond and true or false, true, label)
end

function t.report(name)
	print(("%s: %d passed, %d failed"):format(name, t.passes, t.failures))
	if t.failures > 0 then os.exit(1) end
end

return t
