local t = require "t"
local Diff = require "Diff"

local add, rem = Diff.compute({}, {})
t.eq(add, {}, "empty/empty add"); t.eq(rem, {}, "empty/empty remove")

add, rem = Diff.compute({ 1, 2, 3 }, {})
t.eq(add, { 1, 2, 3 }, "all new"); t.eq(rem, {}, "none removed")

add, rem = Diff.compute({}, { 5, 4 })
t.eq(add, {}, "nothing to add"); t.eq(rem, { 4, 5 }, "all removed, sorted")

add, rem = Diff.compute({ 3, 1, 2 }, { 2, 3, 1 })
t.eq(add, {}, "identical add"); t.eq(rem, {}, "identical remove")

add, rem = Diff.compute({ 1, 2, 3, 3 }, { 3, 4 })
t.eq(add, { 1, 2 }, "partial overlap add (dupes ignored)"); t.eq(rem, { 4 }, "partial overlap remove")

t.report("test_diff")
