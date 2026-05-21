-- lua_of_ocaml runtime: string and bytes operations
--
-- Strings are plain immutable Lua strings.
-- Bytes are a single-cell table { chars_table } where chars_table is
-- a Lua array of integer byte values (0..255), 1-indexed.  This makes
-- per-byte mutation O(1) and avoids the previous representation's
-- O(n²) cost on Buffer.add_string (each blit rebuilt the underlying
-- string with `..` and string.sub).

local math_floor = math.floor
local string_byte = string.byte
local string_char = string.char
-- Lua 5.2+ moved `unpack` to `table.unpack`.  Pick whichever is in
-- scope so this file works on Lua 5.1–5.4 and LuaJIT, even when
-- loaded standalone (the test runner dofiles it directly).
local unpack = unpack or table.unpack

-- ---- Plain strings ----

function caml_string_length(s)
  if s == nil then return 0 end
  return #s * 2
end
caml_ml_string_length = caml_string_length

function caml_string_get(s, i)
  return string_byte(s, math_floor(i / 2) + 1) * 2
end
caml_string_unsafe_get = caml_string_get

function caml_create_string(len)
  return string.rep("\0", math_floor(len / 2))
end

function caml_string_notequal(a, b) return a ~= b end
function caml_string_equal(a, b) return a == b end

function caml_string_compare(a, b)
  if a < b then return -2 elseif a > b then return 2 else return 0 end
end

function caml_string_concat(a, b) return a .. b end

-- ---- Bytes (mutable) ----
-- Internal helpers.  All bytes accessors normalise to a chars table.

local function bytes_chars(b)
  if type(b) == "table" then return b[1] end
  -- A plain string was passed where Bytes was expected — produce a
  -- chars view for it (read-only by convention).
  local t = {}
  for i = 1, #b do t[i] = string_byte(b, i) end
  return t
end

local function bytes_to_string(b)
  if type(b) ~= "table" then return b end
  local chars = b[1]
  local n = #chars
  if n == 0 then return "" end
  -- string.char accepts up to ~8000 args; chunk for safety.
  if n <= 4096 then return string_char(unpack(chars)) end
  local parts = {}
  local i = 1
  while i <= n do
    local j = math.min(i + 4095, n)
    parts[#parts + 1] = string_char(unpack(chars, i, j))
    i = j + 1
  end
  return table.concat(parts)
end

function caml_create_bytes(len)
  local n = math_floor(len / 2)
  local chars = {}
  for i = 1, n do chars[i] = 0 end
  return { chars }
end

function caml_ml_bytes_length(b)
  if b == nil then return 0 end
  if type(b) == "table" then return #b[1] * 2 end
  return #b * 2
end

function caml_bytes_get(b, i)
  local pos = math_floor(i / 2) + 1
  if type(b) == "table" then
    return (b[1][pos] or 0) * 2
  end
  return string_byte(b, pos) * 2
end
caml_bytes_unsafe_get = caml_bytes_get

function caml_bytes_set(b, i, c)
  local pos = math_floor(i / 2) + 1
  local v = math_floor(c / 2) % 256
  if type(b) == "table" then
    b[1][pos] = v
  end
  return 0
end
caml_bytes_unsafe_set = caml_bytes_set

function caml_string_of_bytes(b) return bytes_to_string(b) end
function caml_bytes_of_string(s)
  local t = {}
  for i = 1, #s do t[i] = string_byte(s, i) end
  return { t }
end

function caml_bytes_equal(a, b)
  return bytes_to_string(a) == bytes_to_string(b)
end

function caml_bytes_compare(a, b)
  local sa, sb = bytes_to_string(a), bytes_to_string(b)
  return caml_string_compare(sa, sb)
end

-- caml_blit_string(src, src_ofs, dst, dst_ofs, len)
--   src is a string OR bytes; dst is bytes.
function caml_blit_string(src, ofs1, dst, ofs2, len)
  local o1 = math_floor(ofs1 / 2) + 1
  local o2 = math_floor(ofs2 / 2) + 1
  local ln = math_floor(len / 2)
  if ln <= 0 then return 0 end
  if type(dst) ~= "table" then return 0 end  -- can't blit into a string
  local d = dst[1]
  if type(src) == "table" then
    local s = src[1]
    for k = 0, ln - 1 do d[o2 + k] = s[o1 + k] end
  else
    for k = 0, ln - 1 do d[o2 + k] = string_byte(src, o1 + k) end
  end
  return 0
end
caml_blit_bytes = caml_blit_string

function caml_fill_string(b, ofs, len, c)
  local o = math_floor(ofs / 2) + 1
  local ln = math_floor(len / 2)
  local v = math_floor(c / 2) % 256
  if type(b) ~= "table" then return 0 end
  local d = b[1]
  for k = 0, ln - 1 do d[o + k] = v end
  return 0
end
caml_fill_bytes = caml_fill_string
