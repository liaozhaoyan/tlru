# tlru

 Lru implemented based on lua, supports ttl parameters.

 # Installation

The rapidest way to install tlru is using the package management tools like luarocks.

 ```bash
 luarocks install tlru
 ```

 # Usage

 ```lua
 local tlru = require("tlru")
 local lru = tlru.new(10)
 lru:set("key", "value")
 print(lru:get("key"))
 ```

 # API

 - new(size, autoFlush)
   size: lru size, if set to nil, for ttl conditions, then the lru will no longer limit the number of lru members.
   mode:  lru: pure lru, no ttl; 
          ttl: lru with ttl; 
          flush: lru with ttl and manual flush

 ## member functions

 - count()
 - set(key, value, ttl)  // ttl is optional, just available for ttl/flush mode
 - sets(members)
  members: list format {{key, value, ttl}...}
 - get(key)
 - gets(keys)
   keys: list format{key, key...}
 - delete(key)
 - resize(size)
 - flush()  // only for autoFlush = false
