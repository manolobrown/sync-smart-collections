-- MappingCodec.lua - encode { [smartId] = mirrorId } as a string for catalog:setPropertyForPlugin.
-- Format: "v1|smartId:mirrorId,smartId:mirrorId". Pure Lua, no Lightroom imports.

local MappingCodec = {}

local VERSION = "v1"

function MappingCodec.encode(map)
	local keys = {}
	for k in pairs(map or {}) do keys[#keys + 1] = k end
	table.sort(keys, function(a, b) return tonumber(a) < tonumber(b) end)
	local parts = {}
	for _, k in ipairs(keys) do
		parts[#parts + 1] = tostring(k) .. ":" .. tostring(map[k])
	end
	return VERSION .. "|" .. table.concat(parts, ",")
end

function MappingCodec.decode(str)
	local map = {}
	if type(str) ~= "string" then return map end
	local version, body = str:match("^(v%d+)|(.*)$")
	if version ~= VERSION then return map end
	for pair in body:gmatch("[^,]+") do
		local a, b = pair:match("^(%d+):(%d+)$")
		if a and b then map[tonumber(a)] = tonumber(b) end
	end
	return map
end

return MappingCodec
