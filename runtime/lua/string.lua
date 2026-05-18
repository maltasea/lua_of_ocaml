-- lua_of_ocaml runtime: string and bytes operations
-- Provides: caml_string_length caml_ml_string_length caml_string_get
--           caml_create_string caml_create_bytes caml_ml_bytes_length
--           caml_blit_string caml_blit_bytes caml_fill_string caml_fill_bytes
--           caml_string_notequal caml_string_equal caml_string_compare
--           caml_bytes_compare caml_string_concat caml_string_of_bytes caml_bytes_of_string

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

function caml_create_string(len)
  return string.rep("\0", math_floor(len/2))
end

function caml_create_bytes(len)
  return string.rep("\0", math_floor(len/2))
end

function caml_ml_bytes_length(b)
  if b == nil then return 0 end return #b * 2
end

function caml_blit_string(s1, ofs1, s2, ofs2, len)
  local o1 = math_floor(ofs1 / 2) + 1
  local o2 = math_floor(ofs2 / 2) + 1
  local ln = math_floor(len / 2)
  return string.sub(s2, 1, o2 - 1) .. string.sub(s1, o1, o1 + ln - 1) .. string.sub(s2, o2 + ln)
end

function caml_blit_bytes(s1, ofs1, s2, ofs2, len)
  return caml_blit_string(s1, ofs1, s2, ofs2, len)
end

function caml_fill_string(s, ofs, len, c)
  local o = math_floor(ofs / 2) + 1
  local ln = math_floor(len / 2)
  local char = string.char(math_floor(c / 2))
  return string.sub(s, 1, o - 1) .. string.rep(char, ln) .. string.sub(s, o + ln)
end

function caml_fill_bytes(s, ofs, len, c)
  return caml_fill_string(s, ofs, len, c)
end

function caml_string_notequal(a, b) return a ~= b end
function caml_string_equal(a, b) return a == b end

function caml_string_compare(a, b)
  if a < b then return -2 elseif a > b then return 2 else return 0 end
end

function caml_bytes_compare(a, b)
  return caml_string_compare(a, b)
end

function caml_string_concat(a, b) return a .. b end
function caml_string_of_bytes(s) return s end
function caml_bytes_of_string(s) return s end
