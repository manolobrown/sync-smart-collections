local t = require "t"
local stub = require "lr_stub"
local Scheduler = require "Scheduler"

local cat = stub.catalog
stub.prefs.enabled = true
stub.prefs.pauseInDevelop = true
stub.prefs.notifyStyle = "none"
cat:addSmart("S", nil, stub.photos(1, 3))

-- pause in develop
stub.module = "develop"
local ran, why = Scheduler.runCycle("scheduled")
t.eq({ ran, why }, { false, "develop" }, "skipped in develop")
t.ok(Scheduler.statusText():find("develop") ~= nil, "status mentions skip")

-- manual ignores pause
ran, why = Scheduler.runCycle("manual")
t.eq({ ran, why }, { true, "ok" }, "manual runs in develop")

-- disabled
stub.module = "library"
stub.prefs.enabled = false
ran, why = Scheduler.runCycle("scheduled")
t.eq({ ran, why }, { false, "disabled" }, "skipped when disabled")
stub.prefs.enabled = true

-- syncNow shows a summary bezel
Scheduler.syncNow()
t.ok(stub.bezels[#stub.bezels]:find("1 mirror") ~= nil, "summary bezel: " .. tostring(stub.bezels[#stub.bezels]))

-- errors inside a cycle are caught and reported, not raised
local SyncEngine = require "SyncEngine"
local real = SyncEngine.runCycle
SyncEngine.runCycle = function() error("boom") end
ran, why = Scheduler.runCycle("scheduled")
t.eq({ ran, why }, { true, "error" }, "error captured")
t.ok(Scheduler.statusText():find("boom") ~= nil, "status shows error")
SyncEngine.runCycle = real

-- stop with done callback
local done = false
Scheduler.stop(function() done = true end)
t.ok(done, "done callback invoked")

t.report("test_scheduler")
