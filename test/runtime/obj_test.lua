dofile("runtime/lua/stdlib.lua")
dofile("runtime/lua/obj.lua")

local pass, total = 0, 0
local function check(label, ok)
  total = total + 1
  if ok then pass = pass + 1; print("  OK: " .. label)
  else print("  FAIL: " .. label) end
end

print("=== caml_obj_block ===")
local b = caml_obj_block(42, 1, 2, 3)
check("tag", caml_obj_tag(b) == 42)
check("field 1", b[2] == 1)
check("field 3", b[4] == 3)

print("=== caml_obj_dup ===")
local c = caml_obj_dup(b)
check("dup tag", caml_obj_tag(c) == 42)
check("dup fields", c[2] == 1 and c[4] == 3)
check("independent", c ~= b)

print("=== caml_obj_tag variants ===")
check("nil", caml_obj_tag(nil) == 0)
check("number", caml_obj_tag(42) == 0)
check("string", caml_obj_tag("hi") == 0)

print("=== caml_obj_set_raw_field ===")
local d = caml_obj_block(0, 10, 20)
caml_obj_set_raw_field(d, 0, 99)
check("set raw", d[2] == 99)

print(string.format("obj: %d/%d", pass, total))
if pass < total then os.exit(1) end
