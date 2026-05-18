-- lua_of_ocaml runtime: integer arithmetic and bitwise operations
-- Provides: caml_mul caml_div caml_mod
--           int_and int_or int_xor int_lsl int_lsr int_asr int_add int_sub int_neg
--           caml_and caml_or caml_xor caml_lsl caml_lsr caml_asr
--           caml_eq caml_neq caml_lt caml_le caml_gt caml_ge
--           caml_lessequal caml_greaterequal caml_lessthan caml_greaterthan
--           caml_not caml_is_int

local math_floor = math.floor

function caml_mul(a, b) return math_floor(a * b / 2) end
function caml_div(a, b) return math_floor(math_floor(a / 2) / math_floor(b / 2)) * 2 end
function caml_mod(a, b)
  local a2 = math_floor(a / 2)
  local b2 = math_floor(b / 2)
  local m = a2 % b2
  if m < 0 then m = m + b2 end return m * 2
end

-- Pure-Lua bitwise for Lua 5.1
local function uint_and(a, b)
  local r = 0; local w = 1
  for i = 0, 31 do
    if (a % 2 > 0) and (b % 2 > 0) then r = r + w end
    a = math_floor(a / 2); b = math_floor(b / 2); w = w * 2
  end
  return r
end
local function uint_or(a, b)
  local r = 0; local w = 1
  for i = 0, 31 do
    if (a % 2 > 0) or (b % 2 > 0) then r = r + w end
    a = math_floor(a / 2); b = math_floor(b / 2); w = w * 2
  end
  return r
end
local function uint_xor(a, b)
  local r = 0; local w = 1
  for i = 0, 31 do
    if ((a % 2 > 0) and (b % 2 == 0)) or ((a % 2 == 0) and (b % 2 > 0)) then r = r + w end
    a = math_floor(a / 2); b = math_floor(b / 2); w = w * 2
  end
  return r
end
local function uint_shl(a, b)
  if b >= 32 then return 0 end
  return (a * (2 ^ b)) % (2 ^ 32)
end
local function uint_shr(a, b)
  if b >= 32 then return 0 end
  return math_floor(a / (2 ^ b))
end

function int_and(a, b) return uint_and(math_floor(a/2), math_floor(b/2)) * 2 end
function int_or(a, b)  return uint_or(math_floor(a/2), math_floor(b/2)) * 2 end
function int_xor(a, b) return uint_xor(math_floor(a/2), math_floor(b/2)) * 2 end
function int_lsl(a, b) return uint_shl(math_floor(a/2), math_floor(b/2)) * 2 end
function int_lsr(a, b) return uint_shr(math_floor(a/2), math_floor(b/2)) * 2 end
function int_asr(a, b)
  local a2 = math_floor(a / 2); local b2 = math_floor(b / 2)
  if a2 >= 2^31 then a2 = a2 - 2^32 end
  return math_floor(a2 / (2 ^ b2)) * 2
end
function int_add(a, b) return a + b end
function int_sub(a, b) return a - b end
function int_neg(a) return -a end

caml_and = int_and; caml_or = int_or; caml_xor = int_xor
caml_lsl = int_lsl; caml_lsr = int_lsr; caml_asr = int_asr

function caml_eq(a, b) return a == b end
function caml_neq(a, b) return a ~= b end
function caml_lt(a, b) return a < b end
function caml_le(a, b) return a <= b end
function caml_gt(a, b) return a > b end
function caml_ge(a, b) return a >= b end
function caml_lessequal(a, b) return a <= b end
function caml_greaterequal(a, b) return a >= b end
function caml_lessthan(a, b) return a < b end
function caml_greaterthan(a, b) return a > b end

function caml_not(x) return (x == 0) and 2 or 0 end
function caml_is_int(x) return type(x) == "number" end
