-- FFI: OCaml <-> Lua interop tests

dofile("runtime/lua/stdlib.lua")
dofile("runtime/lua/ints.lua")
dofile("runtime/lua/obj.lua")
dofile("runtime/lua/fail.lua")
dofile("runtime/lua/string.lua")
dofile("runtime/lua/io.lua")
dofile("runtime/lua/misc.lua")

local pass = 0
local total = 0

local function check(label, ok)
  total = total + 1
  if ok then
    pass = pass + 1
    print("  OK: " .. label)
  else
    print("  FAIL: " .. label)
  end
end

print("=== FFI Call Tests ===")

check("lu_add(4,6) == 10", lu_add(4, 6) == 10)
check("lu_add(10,20) == 30", lu_add(10, 20) == 30)
check("lu_add(-2, 2) == 0", lu_add(-2, 2) == 0)

print("=== FFI String Tests ===")

check("caml_string_concat", caml_string_concat("hi ", "there") == "hi there")
check("caml_string_length", caml_string_length("hello") == 5)

print("=== FFI Int Math Tests ===")

check("caml_mul(6,8)", caml_mul(6, 8) == 24)     -- 3*4=12, tagged=24
check("caml_div(12,4)", caml_div(12, 4) == 6)     -- 6/2=3, tagged=6
check("int_add(2,6)", int_add(2, 6) == 8)
check("int_sub(10,4)", int_sub(10, 4) == 6)

print("=== FFI Bitwise Tests ===")

check("int_and(10,12) == 8", int_and(10, 12) == 8)
check("int_or(10,12) == 14", int_or(10, 12) == 14)
check("int_xor(10,12) == 6", int_xor(10, 12) == 6)
check("int_lsl(4,6) -> lsl -> lsr", int_lsr(int_lsl(4, 6), 6) == 4)

print("=== FFI Object Tests ===")

check("caml_obj_block", caml_obj_tag(caml_obj_block(42, 1, 2)) == 42)
check("caml_obj_dup", caml_obj_tag(caml_obj_dup({10, 20, 30})) == 10)

print("=== FFI Callback Tests ===")

caml_register_named_value("ffi_cb", function(x) return x + 6 end)
local cb = caml_global_data["ffi_cb"]
check("register + call callback", cb(10) == 16)

print("=== FFI I/O Tests ===")

local out = ""
-- can't easily capture io.write, but we can test it doesn't crash
check("caml_ml_output no crash", pcall(function()
  caml_ml_output(0, "test", 0, 4)
end))

print("---")
print(string.format("FFI: %d/%d passed", pass, total))
if pass < total then os.exit(1) end
