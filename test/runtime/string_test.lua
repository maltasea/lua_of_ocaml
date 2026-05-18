dofile("runtime/lua/string.lua")

local pass, total = 0, 0
local function check(label, ok)
  total = total + 1
  if ok then pass = pass + 1; print("  OK: " .. label)
  else print("  FAIL: " .. label) end
end

print("=== string length ===")
check("hello=5", caml_string_length("hello") == 5)
check("empty=0", caml_string_length("") == 0)

print("=== string_concat ===")
check("concat", caml_string_concat("hello ", "world") == "hello world")

print("=== string_equal ===")
check("equal", caml_string_equal("abc", "abc"))
check("notequal", caml_string_notequal("abc", "def"))

print("=== string_compare ===")
check("abc<def", caml_string_compare("abc", "def") == -2)
check("abc=abc", caml_string_compare("abc", "abc") == 0)
check("def>abc", caml_string_compare("def", "abc") == 2)

print("=== create/blit ===")
check("create", #caml_create_string(20) == 10)
check("blit", caml_blit_string("ab", 0, "xxxx", 0, 4) == "abxx")

print("=== fill ===")
check("fill", caml_fill_string("xxxx", 4, 4, 194) == "xxaa")

print(string.format("string: %d/%d", pass, total))
if pass < total then os.exit(1) end
