dofile("runtime/lua/ints.lua")
dofile("runtime/lua/stdlib.lua")
dofile("runtime/lua/misc.lua")

print("=== OCaml -> Lua FFI ===")
print("")

print("1. OCaml 'external lua_add' calls Lua lua_add(10,20):")
print("   result = " .. lua_add(10, 20))

print("")
print("2. OCaml 'external lua_greet' calls Lua lua_greet('ocaml'):")
lua_greet("ocaml")

print("")
print("3. OCaml 'external os_date' calls Lua os.date:")
print("   result = " .. os_date("%Y-%m-%d"))

print("")
print("4. Lua calls back OCaml closure stored in caml_global_data:")
caml_register_named_value("my_cb", function(x) return x + 10 end)
local cb = caml_global_data["my_cb"]
print("   my_cb(20) = " .. cb(20))

print("")
print("=== done ===")
