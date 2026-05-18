dofile("runtime/lua/stdlib.lua")
dofile("runtime/lua/ints.lua")
dofile("runtime/lua/obj.lua")
dofile("runtime/lua/fail.lua")
dofile("runtime/lua/string.lua")
dofile("runtime/lua/io.lua")
dofile("runtime/lua/misc.lua")

local pass, total = 0, 0
local function check(label, ok)
  total = total + 1
  if ok then pass = pass + 1; print("  OK: " .. label)
  else print("  FAIL: " .. label) end
end

check("lua_add(4,6)", lua_add(4,6) == 10)
check("lua_add(10,20)", lua_add(10,20) == 30)
check("caml_mul(6,8)", caml_mul(6,8) == 24)
check("int_add(2,6)", int_add(2,6) == 8)
check("int_and(10,12)", int_and(10,12) == 8)
check("int_or(10,12)", int_or(10,12) == 14)
check("int_lsl(4,6)", int_lsl(4,6) == 32)
check("caml_obj_tag", caml_obj_tag(caml_obj_block(42,1)) == 42)
check("caml_string_concat", caml_string_concat("a","b") == "ab")
check("callback", pcall(function()
  caml_register_named_value("cb", function(x) return x+6 end)
  return caml_global_data["cb"](10) == 16
end) and true or false)
check("caml_ml_output", pcall(function() caml_ml_output(0,"x",0,2) end))

print(string.format("\n%d/%d passed", pass, total))
if pass < total then os.exit(1) end
