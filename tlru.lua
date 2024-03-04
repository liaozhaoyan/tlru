-- tlru, LRU cache in Lua, 
-- Copyright (c) 2024 liaozhaoyan

local lrbtree = require "lrbtree"
local socket = require("socket")

local tlru = {}

function tlru.new(maxSize, auto)
    if maxSize then
        assert(maxSize >= 1, "maxSize must be >= 1")
    end
    if auto == nil then
        auto = true  --> default true
    end

    local size = 0
    local rbTime = lrbtree.new(function (a, b) return a - b end)
    local tMap = {}

    -- map is a hash map from keys to tuples
    -- tuple: value, prev, next, key
    -- prev and next are pointers to tuples
    local map = {}

    -- indices of tuple
    local VALUE = 1
    local PREV  = 2
    local NEXT  = 3
    local KEY   = 4
    local TTL   = 5

    -- newest and oldest are ends of double-linked list
    local newest = nil -- first
    local oldest = nil -- last

    local removedTuple -- created in del(), removed in set()

    -- remove a tuple from linked list
    local function cut(tuple)
        local tuple_prev = tuple[PREV]
        local tuple_next = tuple[NEXT]
        tuple[PREV] = nil
        tuple[NEXT] = nil
        if tuple_prev and tuple_next then
            tuple_prev[NEXT] = tuple_next
            tuple_next[PREV] = tuple_prev
        elseif tuple_prev then
            -- tuple is the oldest element
            tuple_prev[NEXT] = nil
            oldest = tuple_prev
        elseif tuple_next then
            -- tuple is the newest element
            tuple_next[PREV] = nil
            newest = tuple_next
        else
            -- tuple is the only element
            newest = nil
            oldest = nil
        end
    end

    -- insert a tuple to the newest end
    local function setNewest(tuple)
        if not newest then
            newest = tuple
            oldest = tuple
        else
            tuple[NEXT] = newest
            newest[PREV] = tuple
            newest = tuple
        end
    end

    local function del(key, tuple)
        map[key] = nil
        cut(tuple)
        size = size - 1
        removedTuple = tuple
    end

    local function overDelete(ttl, key)
        local lMap = tMap[ttl]
        lMap[key] = nil
        if next(lMap) == nil then  -- lMap is empty, delete it.
            tMap[ttl] = nil
            rbTime:delete(ttl)
        end
    end

    -- removes elemenets to provide enough memory
    -- returns last removed element or nil
    local function makeFreeSpace()
        if maxSize  then
            while size >= maxSize do
                local key = oldest[KEY]
                overDelete(oldest[TTL], key)
                del(key, oldest)
            end
        end
    end

    local function ttlDelete(now)
        local first = rbTime:first()
        while first and now >= first do
            local keys = tMap[first]
            for key, _ in pairs(keys) do
                del(key, map[key])
            end
            rbTime:pop()
            first = rbTime:first()
        end
    end

    local function count(_)
        if auto then ttlDelete(os.time()) end
        return size
    end

    local function _get(key)
        local tuple = map[key]
        if not tuple then
            return nil
        end
        cut(tuple)
        setNewest(tuple)
        return tuple[VALUE]
    end

    local function get(_, key)
        if auto then ttlDelete(os.time()) end

        return _get(key)
    end

    local function gets(_, keys)
        if auto then ttlDelete(os.time()) end

        local maps = {}
        for _, key in ipairs(keys) do
            maps[key] = _get(key)
        end
        return maps
    end

    local function _set(key, value, lifeTime)
        local tuple = map[key]
        if tuple then
            overDelete(tuple[TTL], key)
            del(key, tuple)
        end
        local ts1, ts2 = 0, 0
        
        if value then
            -- the value is not removed
            makeFreeSpace()

            local newTuple = removedTuple or {nil, nil, nil, nil, nil}
            map[key] = newTuple
            newTuple[VALUE] = value
            newTuple[KEY] = key
            newTuple[TTL] = lifeTime
            size = size + 1
            setNewest(newTuple)

            local lMap = tMap[lifeTime]
            if lMap then
                ts1 = socket.gettime()
                lMap[key] = true   --> The code executes very slowly here, even slower than pure lua, I don't know why.
                ts2 = socket.gettime()
            else
                tMap[lifeTime] = {[key] = 1}
                rbTime:insert(lifeTime)
            end
        else
            assert(key ~= nil, "Key may not be nil")
        end
        removedTuple = nil
        return ts2 - ts1
    end

    
    local function set(_, key, value, ttl)
        ttl = ttl or math.huge
        assert(ttl > 0, "TTL must be > 0")

        local now = os.time()
        if auto then ttlDelete(now) end
    
        return _set(key, value, ttl + now)
    end

    local function sets(_, items)
        local now = os.time()
        if auto then ttlDelete(now) end

        for _, item in ipairs(items) do
            _set(item[1], item[2], item[3] and item[3] + now or math.huge)
        end
    end

    local function delete(o, key)
        return set(o, key, nil)
    end

    local function Next(_, prev_key)
        local tuple
        if prev_key then
            tuple = map[prev_key][NEXT]
        else
            tuple = newest
        end
        if tuple then
            return tuple[KEY], tuple[VALUE]
        else
            return nil
        end
    end

    local function resize(_, var)
        if auto then ttlDelete(os.time()) end
        if var then
            maxSize = var + 1
            makeFreeSpace()
            maxSize = var
        else
            maxSize = nil
        end
    end

    -- returns iterator for keys and values
    local function lruPairs()
        if auto then ttlDelete(os.time()) end
        return Next, nil, nil
    end

    local function flush(_)
        ttlDelete(os.time())
    end

    local mt = {
        __index = {
            get = get,
            gets = gets,
            set = set,
            sets = sets,
            count = count,
            delete = delete,
            resize = resize,
            pairs = lruPairs
        },
        __newindex = function (o, key, value) return o:set(key, value) end,
        __call = function (o, key) return o:get(key) end
    }
    if not auto then
        mt.__index.flush = flush
    end

    return setmetatable({}, mt)
end

return tlru