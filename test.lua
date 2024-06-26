local tlru = require("tlru")
local socket = require("socket")

local function baseTest(mode)
    local lru = tlru.new(10, mode)
    assert(lru:count() == 0)
    assert(lru.max() == 10)

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
    assert(lru.max() == 10)

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

    -- for sets and gets
    lru = tlru.new(4, mode)
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

    -- test with resize
    lru = tlru.new(nil, mode)
    local M = 1000
    for i = 1, M do
        lru:set(i, i)
    end
    assert(lru:count() == M)
    lru:resize(100)   -->reduce
    assert(lru:count() == 100, string.format("count: %d", lru:count()))
    lru:resize(M)     -->expand
    assert(lru:count() == 100)
    for i = 1, M do
        lru:set(i, i)
    end
    assert(lru:get(1) == 1)
    assert(lru:count() == M)

    -- for huge test
    lru = tlru.new(1000, mode)
    local N = 10000000
    for i = 1, N do
        lru:set(i, i)
    end
    assert(lru:count() == 1000)
    local count = 0
    for k, v in lru:pairs() do
        assert(v == k)
        count = count + 1
    end
    assert(count == lru:count(), string.format("hope: %d, get:%d", count, lru:count()))
end

baseTest("lru")
baseTest("ttl")
baseTest("flush")

local lru

-- test with ttl
lru = tlru.new(4, "ttl")

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
lru = tlru.new(4, "ttl")

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

-- test with flush
lru = tlru.new(nil, "flush")
assert(lru.flush ~= nil)  -- if auto is false, flush will set.
assert(lru:count() == 0)
local L = 5
for i = 1, L do
    lru:set(i, i, i)
end
assert(lru:get(1) == 1)
assert(lru:count() == L)

socket.sleep(1)
assert(lru:count() == L)
lru:flush()
assert(lru:count() == L - 1)
assert(lru:get(1) == nil)
assert(lru:get(2) == 2)
lru:delete(2)
assert(lru:get(2) == nil)
assert(lru:count() == L - 2)
socket.sleep(L - 1)
assert(lru:count() == L - 2)
lru:flush()
assert(lru:count() == 0)

print("lru test suceeded.")
