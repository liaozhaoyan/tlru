-- tlru, LRU cache in Lua, 
-- Copyright (c) 2024 liaozhaoyan

local lrbtree = require "lrbtree"

local time = os.time
local pairs = pairs
local ipairs = ipairs
local setmetatable = setmetatable
local mathHuge = math.huge

local tlru = {}

local modeMap = {
    lru = true,
    ttl = true,
    flush = true
}

function tlru.new(maxSize, mode)
    -- mode lru: pure lru, no ttl; 
    --      ttl: lru with ttl; 
    --      flush: lru with ttl and manual flush
    if maxSize then
        assert(maxSize >= 1, "maxSize must be >= 1")
    end
    mode = mode or "lru"
    assert(modeMap[mode], "mode must be lru, ttl or flush")

    local size = 0
    local rbTime, tMap
    if mode ~= 'lru' then
        rbTime = lrbtree.new(function (a, b) return a - b end)
        tMap = {}
    end

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
        if maxSize then
            while size >= maxSize do
                local key = oldest[KEY]
                overDelete(oldest[TTL], key)
                del(key, oldest)
            end
        end
    end

    -- no ttl option
    local function makeFreeSpaceLru()
        if maxSize  then
            while size >= maxSize do
                local key = oldest[KEY]
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
        return size
    end

    local function countFlush(_)
        ttlDelete(time())
        return size
    end

    local function max(_)
        return maxSize
    end

    local function maxFlush(_)
        ttlDelete(time())
        return maxSize
    end

    local function _get(key)
        local tuple = map[key]
        if not tuple then
            return nil
        end
        
        if newest == tuple then  -- aleady newest
            return tuple[VALUE]
        end

        cut(tuple)
        setNewest(tuple)
        return tuple[VALUE]
    end

    local function get(_, key)
        return _get(key)
    end

    local function getFlush(_, key)
        ttlDelete(time())
        return _get(key)
    end

    local function gets(_, keys)
        local maps = {}
        for _, key in ipairs(keys) do
            maps[key] = _get(key)
        end
        return maps
    end

    local function getsFlush(o, keys)
        ttlDelete(time())

        return gets(o, keys)
    end

    local function _set(key, value, lifeTime)
        local tuple = map[key]
        if tuple then
            overDelete(tuple[TTL], key)
            del(key, tuple)
        end
        
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
                lMap[key] = true   --> The code executes very slowly here, even slower than pure lua, I don't know why.
            else
                tMap[lifeTime] = {[key] = 1}
                rbTime:insert(lifeTime)
            end
        else
            assert(key ~= nil, "Key may not be nil")
        end
        removedTuple = nil
    end

    local function setLru(_, key, value)
        local tuple = map[key]
        if tuple then
            del(key, tuple)
        end

        if value then
            -- the value is not removed
            makeFreeSpaceLru()

            local newTuple = removedTuple or {nil, nil, nil, nil, nil}
            map[key] = newTuple
            newTuple[VALUE] = value
            newTuple[KEY] = key
            size = size + 1
            setNewest(newTuple)
        else
            assert(key ~= nil, "Key may not be nil")
        end
        removedTuple = nil
    end
    
    local function set(_, key, value, ttl)
        ttl = ttl or mathHuge
        assert(ttl > 0, "TTL must be > 0")

        local now = time()
    
        return _set(key, value, ttl + now)
    end

    local function setFlush(_, key, value, ttl)
        ttl = ttl or mathHuge
        assert(ttl > 0, "TTL must be > 0")

        local now = time()
        ttlDelete(now)
    
        return _set(key, value, ttl + now)
    end

    local function setsLru(o, items)
        for _, item in ipairs(items) do
            setLru(o, item[1], item[2])
        end
    end

    local function sets(_, items)
        local now = time()

        for _, item in ipairs(items) do
            _set(item[1], item[2], item[3] and item[3] + now or mathHuge)
        end
    end

    local function setsFlush(_, items)
        local now = time()
        ttlDelete(now)
        
        for _, item in ipairs(items) do
            _set(item[1], item[2], item[3] and item[3] + now or mathHuge)
        end
    end

    local function deleteLru(o, key)
        return setLru(o, key, nil)
    end

    local function delete(o, key)
        return set(o, key, nil)
    end

    local function deleteFlush(o, key)
        ttlDelete(time())
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

    local function resizeLru(_, var)
        if var then
            maxSize = var + 1
            makeFreeSpaceLru()
            maxSize = var
        else
            maxSize = nil
        end
    end

    local function resize(_, var)
        if var then
            maxSize = var + 1
            makeFreeSpace()
            maxSize = var
        else
            maxSize = nil
        end
    end

    local function resizeFlush(o, var)
        ttlDelete(time())
        return resize(o, var)
    end

    -- returns iterator for keys and values
    local function lruPairs(_)
        return Next, nil, nil
    end

    local function lruPairsFlush(_)
        ttlDelete(time())
        return Next, nil, nil
    end

    local function flush(_)
        ttlDelete(time())
    end

    local mt
    if mode == "ttl" then  -- automatic flush
        mt = {
            __index = {
                get = getFlush,
                gets = getsFlush,
                set = setFlush,
                sets = setsFlush,
                count = countFlush,
                max = maxFlush,
                delete = deleteFlush,
                resize = resizeFlush,
                pairs = lruPairsFlush,
            },
            __newindex = function (o, key, value) return o:set(key, value) end,
            __call = function (o, key) return o:get(key) end
        }
    elseif mode == "flush" then
        mt = {
            __index = {
                get = get,
                gets = gets,
                set = set,
                sets = sets,
                count = count,
                max = max,
                delete = delete,
                resize = resize,
                pairs = lruPairs,
                flush = flush
            },
            __newindex = function (o, key, value) return o:set(key, value) end,
            __call = function (o, key) return o:get(key) end
        }
    else  -- pure lru mode, no ttl
        mt = {
            __index = {
                get = get,
                gets = gets,
                set = setLru,
                sets = setsLru,
                count = count,
                max = max,
                delete = deleteLru,
                resize = resizeLru,
                pairs = lruPairs,
            },
            __newindex = function (o, key, value) return o:set(key, value) end,
            __call = function (o, key) return o:get(key) end
        }
    end

    return setmetatable({}, mt)
end

return tlru