local tlru = require("tlru")
local socket = require("socket")


-- base test, without ttl
local lru = tlru.new(10)
assert(lru:count() == 0)

lru:set("a", 1)
assert(lru:count() == 1)
lru:set("b", 2)
lru:set("c", 3)
lru:set("d", 4)
lru:set("e", 5)
lru:set("f", 6)
lru:set("g", 7)
lru:set("h", 8)
lru:set("i", 9)
lru:set("j", 10)
assert(lru:count() == 10)

assert(lru:get("a") == 1)
assert(lru:get("b") == 2)
assert(lru:get("c") == 3)
assert(lru:get("d") == 4)
assert(lru:get("e") == 5)
assert(lru:get("f") == 6)
assert(lru:get("g") == 7)
assert(lru:get("h") == 8)
assert(lru:get("i") == 9)
assert(lru:get("j") == 10)

lru:set("k", 11)
assert(lru:get("a") == nil)
assert(lru:get("b") == 2)
assert(lru:get("k") == 11)

lru:set("b", 1)
assert(lru:get("b") == 1)

lru:delete("b")
assert(lru:get("b") == nil)
assert(lru:count() == 9)

-- lru:set("a", 2)
lru['a'] = 2
assert(lru("a") == 2)
lru["set"] = 10
lru['a'] = 1
assert(lru("a") == 1)
assert(lru("c") == nil)

assert(lru:count() == 10)


-- test with ttl
lru = tlru.new(4)

lru:set("a", 1, 1)
lru:set("b", 2, 2)
lru:set("c", 3, 3)
lru:set("d", 4, 4)

assert(lru:count() == 4)
assert(lru:get("a") == 1)
assert(lru:get("b") == 2)
assert(lru:get("c") == 3)
assert(lru:get("d") == 4)

socket.sleep(1)
assert(lru:count() == 3, string.format("count: %d", lru:count()))
assert(lru:get("a") == nil)
assert(lru:get("b") == 2)

socket.sleep(1)
assert(lru:count() == 2, string.format("count: %d", lru:count()))
assert(lru:get("a") == nil)
assert(lru:get("b") == nil)
assert(lru:get("c") == 3)


socket.sleep(2)
assert(lru:count() == 0, string.format("count: %d", lru:count()))
assert(lru:get("a") == nil)
assert(lru:get("b") == nil)
assert(lru:get("c") == nil)
assert(lru:get("d") == nil)

lru:set("a", 1, 1)
lru:set("b", 2, 2)
lru:set("c", 3, 3)
lru:set("d", 4, 4)
assert(lru:count() == 4)
assert(lru:get("a") == 1)
assert(lru:get("b") == 2)
assert(lru:get("c") == 3)
assert(lru:get("d") == 4)


-- test with sets and gets
lru = tlru.new(4)

local maps = {
    {'a', 1, 1},
    {'b', 2, 2},
    {'c', 3, 3},
    {'d', 4, 4},
}

lru:sets(maps)
assert(lru:count() == 4)
assert(lru:get("a") == 1)
local res = lru:gets({"a", "b", "c", "d"})
assert(res['a'] == 1)
assert(res['b'] == 2)
assert(res['c'] == 3)
assert(res['d'] == 4)

socket.sleep(1)
assert(lru:count() == 3, string.format("count: %d", lru:count()))
assert(lru:get("a") == nil)
assert(lru:get("b") == 2)
socket.sleep(3)
assert(lru:count() == 0, string.format("count: %d", lru:count()))
local res = lru:gets({"a", "b", "c", "d"})
local cnt = 0
for _ in pairs(res) do
    cnt = cnt + 1
end
assert(cnt == 0)

-- for huge test
lru = tlru.new(1000)
local N = 1000000
for i = 1, N do
    lru:set(i, i)
end
assert(lru:count() == 1000)
