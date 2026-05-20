-- lua_of_ocaml runtime: standard library (globals, call support)
-- Provides: caml_register_global caml_register_named_value caml_get_global
--           caml_fresh_oo_id caml_call_gen caml_set_global caml_bind_frame
--           caml_equal caml_notequal

local math_floor = math.floor

caml_global_data = {}

-- Structural equality / comparison.
-- OCaml values in Lua: ints/strings/bools/nil compare directly; blocks are
-- tables {tag, f1, f2, ...}; lists are {0, hd, tl} terminated by 0;
-- floats are boxed as {253, v}.  Cycles are not handled.
local function _eq(a, b)
  if a == b then return true end
  local ta, tb = type(a), type(b)
  if ta ~= tb then return false end
  if ta ~= "table" then return false end
  local na, nb = #a, #b
  if na ~= nb then return false end
  for i = 1, na do
    if not _eq(a[i], b[i]) then return false end
  end
  return true
end

local function _cmp(a, b)
  if a == b then return 0 end
  local ta, tb = type(a), type(b)
  if ta == "number" and tb == "number" then
    if a < b then return -1 else return 1 end
  end
  if ta == "string" and tb == "string" then
    if a < b then return -1 elseif a > b then return 1 else return 0 end
  end
  if ta == "table" and tb == "table" then
    local na, nb = #a, #b
    local n = (na < nb) and na or nb
    for i = 1, n do
      local c = _cmp(a[i], b[i])
      if c ~= 0 then return c end
    end
    if na < nb then return -1 elseif na > nb then return 1 else return 0 end
  end
  -- Fallback: order by type name
  if ta < tb then return -1 elseif ta > tb then return 1 else return 0 end
end

function caml_equal(a, b)    return _eq(a, b) end
function caml_notequal(a, b) return not _eq(a, b) end
function caml_compare(a, b)  return _cmp(a, b) * 2 end
function caml_lessthan(a, b)    return _cmp(a, b) < 0 end
function caml_lessequal(a, b)   return _cmp(a, b) <= 0 end
function caml_greaterthan(a, b) return _cmp(a, b) > 0 end
function caml_greaterequal(a,b) return _cmp(a, b) >= 0 end

function caml_register_global(id, name, v)
  caml_global_data[id + 1] = v
  caml_global_data[name] = v
end

function caml_register_named_value(name, v)
  caml_global_data[name] = v
  return 0
end

function caml_get_global(id)
  return caml_global_data[id + 1]
end

caml_oo_last_id = 0
function caml_fresh_oo_id(_)
  caml_oo_last_id = caml_oo_last_id + 1
  return caml_oo_last_id * 2
end

function caml_set_global(name, value)
  _G[name] = value
end

function caml_bind_frame(f)
  local param_names = f[3]
  local arg_values = f[4]
  for i = 1, #param_names do
    _G[param_names[i]] = arg_values[i]
  end
end

function caml_call_gen(f, ...)
  local arity = f.arity or 0
  local nargs = select("#", ...)
  if arity == nargs then
    return f(...)
  elseif arity < nargs then
    local args = { ... }
    local r = f(unpack(args, 1, arity))
    for i = arity + 1, nargs do r = r(args[i]) end
    return r
  else
    local args = { ... }
    return function(...)
      local all = {}
      for i = 1, nargs do all[i] = args[i] end
      for i = 1, select("#", ...) do all[nargs + i] = select(i, ...) end
      if #all >= arity then
        return caml_call_gen(f, unpack(all, 1, arity))
      else
        return caml_call_gen(f, unpack(all))
      end
    end
  end
end
