dofile("runtime/lua/ints.lua")

local pass, total = 0, 0
local function check(label, ok)
  total = total + 1
  if ok then pass = pass + 1; print("  OK: " .. label)
  else print("  FAIL: " .. label) end
end

print("=== caml_mul ===")
check("4*6=12", caml_mul(4, 6) == 12)
check("0*x=0", caml_mul(0, 10) == 0)
check("negative", caml_mul(-4, 6) == -12)

print("=== caml_div ===")
check("12/4=3", caml_div(12, 4) == 6)
check("7/2=3", caml_div(14, 4) == 6)

print("=== caml_mod ===")
check("10%6=2", caml_mod(10, 6) == 4)
check("5%3=2", caml_mod(10, 6) == 4)

print("=== int_and ===")
check("6&10=2", int_and(12, 20) == 4)

print("=== int_or ===")
check("6|10=14", int_or(12, 20) == 28)

print("=== int_xor ===")
check("6^10=12", int_xor(12, 20) == 24)

print("=== shifts ===")
check("lsl", int_lsl(4, 6) == 32)
check("lsr", int_lsr(64, 6) == 8)

print(string.format("ints: %d/%d", pass, total))
if pass < total then os.exit(1) end
