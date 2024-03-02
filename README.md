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

 - new(size)

 ## member functions

 - count()
 - set(key, value, ttl)
 - sets(members)
  members: list format {{key, value, ttl}...}
 - get(key)
 - gets(keys)
   keys: list format{key, key...}
 - delete(key)
