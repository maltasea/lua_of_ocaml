-- lua_of_ocaml runtime: string and bytes operations
-- Bytes are mutable table-wrapped strings: {str}. Strings are plain Lua strings.

local math_floor = math.floor

function caml_string_length(s)
  if s == nil then return 0 end return #s * 2
end

function caml_ml_string_length(s)
  if s == nil then return 0 end return #s * 2
end

function caml_string_get(s, i)
  return string.byte(s, math_floor(i/2) + 1) * 2
end
caml_string_unsafe_get = caml_string_get

-- Bytes get/set.  Bytes are { str } — mutate the str slot in place.
function caml_bytes_get(b, i)
  local s = type(b) == "table" and b[1] or b
  return string.byte(s, math_floor(i/2) + 1) * 2
end
caml_bytes_unsafe_get = caml_bytes_get

function caml_bytes_set(b, i, c)
  local s = type(b) == "table" and b[1] or b
  local pos = math_floor(i/2) + 1
  local ch = string.char(math_floor(c/2) % 256)
  local r = string.sub(s, 1, pos - 1) .. ch .. string.sub(s, pos + 1)
  if type(b) == "table" then b[1] = r end
  return 0
end
caml_bytes_unsafe_set = caml_bytes_set

function caml_create_string(len)
  return string.rep("\0", math_floor(len/2))
end

-- Bytes: mutable table {str}
function caml_create_bytes(len)
  return { string.rep("\0", math_floor(len/2)) }
end

function caml_ml_bytes_length(b)
  if b == nil then return 0 end
  local s = type(b) == "table" and b[1] or b
  return #s * 2
end

function caml_blit_string(s1, ofs1, s2, ofs2, len)
  local src = type(s1) == "table" and s1[1] or s1
  local dst = type(s2) == "table" and s2[1] or s2
  local o1 = math_floor(ofs1 / 2) + 1
  local o2 = math_floor(ofs2 / 2) + 1
  local ln = math_floor(len / 2)
  local result = string.sub(dst, 1, o2 - 1) .. string.sub(src, o1, o1 + ln - 1) .. string.sub(dst, o2 + ln)
  if type(s2) == "table" then s2[1] = result end
  return result
end

function caml_blit_bytes(s1, ofs1, s2, ofs2, len)
  return caml_blit_string(s1, ofs1, s2, ofs2, len)
end

function caml_fill_string(s, ofs, len, c)
  local str = type(s) == "table" and s[1] or s
  local o = math_floor(ofs / 2) + 1
  local ln = math_floor(len / 2)
  local char = string.char(math_floor(c / 2))
  local result = string.sub(str, 1, o - 1) .. string.rep(char, ln) .. string.sub(str, o + ln)
  if type(s) == "table" then s[1] = result end
  return result
end

function caml_fill_bytes(s, ofs, len, c)
  return caml_fill_string(s, ofs, len, c)
end

function caml_string_notequal(a, b) return a ~= b end
function caml_string_equal(a, b) return a == b end
function caml_bytes_equal(a, b)
  local sa = type(a) == "table" and a[1] or a
  local sb = type(b) == "table" and b[1] or b
  return sa == sb
end

function caml_string_compare(a, b)
  if a < b then return -2 elseif a > b then return 2 else return 0 end
end

function caml_bytes_compare(a, b)
  local sa = type(a) == "table" and a[1] or a
  local sb = type(b) == "table" and b[1] or b
  return caml_string_compare(sa, sb)
end

function caml_string_concat(a, b) return a .. b end

function caml_string_of_bytes(s)
  if type(s) == "table" then return s[1] end
  return s
end

function caml_bytes_of_string(s) return { s } end
