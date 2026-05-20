-- lua_of_ocaml runtime: array and vector operations
-- Provides: caml_vect_length caml_array_get caml_array_set
--           caml_array_unsafe_get caml_array_unsafe_set
--           caml_array_{get,set}_addr caml_array_{unsafe_get,unsafe_set}_addr
--           caml_array_{get,set}_float caml_array_{unsafe_get,unsafe_set}_float
--           caml_array_make caml_make_vect caml_array_sub caml_array_append
--           caml_array_blit caml_array_fill caml_array_concat

local math_floor = math.floor

function caml_vect_length(v) return (#v - 1) * 2 end
function caml_array_get(v, i) return v[math_floor(i / 2) + 2] or 0 end
function caml_array_set(v, i, x) v[math_floor(i / 2) + 2] = x; return 0 end
function caml_array_unsafe_get(v, i) return caml_array_get(v, i) end
function caml_array_unsafe_set(v, i, x) return caml_array_set(v, i, x) end

-- Typed accessors used by ocamlc bytecode (arrays of values / floats).
-- We don't distinguish layouts here; the generic accessor is correct.
caml_array_get_addr = caml_array_get
caml_array_set_addr = caml_array_set
caml_array_unsafe_get_addr = caml_array_unsafe_get
caml_array_unsafe_set_addr = caml_array_unsafe_set
caml_array_get_float = caml_array_get
caml_array_set_float = caml_array_set
caml_array_unsafe_get_float = caml_array_unsafe_get
caml_array_unsafe_set_float = caml_array_unsafe_set

function caml_array_make(n, init)
  local len = math_floor(n / 2)
  local v = { 0 }
  for i = 1, len do v[i + 1] = init end
  return v
end
caml_make_vect = caml_array_make
caml_array_create = caml_array_make

function caml_array_sub(a, ofs, len)
  ofs = math_floor(ofs / 2); len = math_floor(len / 2)
  local r = { 0 }
  for i = 1, len do r[i + 1] = a[ofs + i + 1] end
  return r
end

function caml_array_append(a, b)
  local r = { 0 }
  local la, lb = #a - 1, #b - 1
  for i = 1, la do r[i + 1] = a[i + 1] end
  for i = 1, lb do r[la + i + 1] = b[i + 1] end
  return r
end

function caml_array_concat(lst)
  -- lst is an OCaml list: {0, hd, tl} | 0
  local r = { 0 }
  local n = 1
  while lst ~= 0 and type(lst) == "table" do
    local a = lst[2]
    for i = 2, #a do n = n + 1; r[n] = a[i] end
    lst = lst[3]
  end
  return r
end

function caml_array_blit(src, sofs, dst, dofs, len)
  sofs = math_floor(sofs / 2); dofs = math_floor(dofs / 2); len = math_floor(len / 2)
  for i = 0, len - 1 do dst[dofs + i + 2] = src[sofs + i + 2] end
  return 0
end

function caml_array_fill(a, ofs, len, x)
  ofs = math_floor(ofs / 2); len = math_floor(len / 2)
  for i = 0, len - 1 do a[ofs + i + 2] = x end
  return 0
end
