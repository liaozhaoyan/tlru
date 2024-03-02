local tlru = require("tlru")
local lru = require("lru")
local socket = require("socket")


local cache
local N = 8000000
local M = 1000
local ts1, ts2

ts1 = socket.gettime()
cache = lru.new(M)
for i = 1, N do
    cache:set(i, i)
end
ts2 = socket.gettime()
local cnt = 0
for _ in cache:pairs() do
    cnt = cnt + 1
end
assert(cnt == M, string.format("cnt:%d, M:%d", cnt, M))
print("lru used:", ts2 - ts1)


cache = tlru.new(M)
ts1 = socket.gettime()
for i = 1, N do
    cache:set(i, i)
end
ts2 = socket.gettime()
assert(cache:count() == M)
print("tlru used:", ts2 - ts1)