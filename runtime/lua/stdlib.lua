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

-- Arity table: maps closure functions to their declared parameter count.
-- Weak keys so closures can be GC'd.
caml_arity = setmetatable({}, { __mode = "k" })

function caml_mkclosure(n, f)
  caml_arity[f] = n
  return f
end

-- Handles partial / exact / over-application correctly for OCaml-curried
-- semantics.  When arity is unknown (e.g. host Lua function from FFI), we
-- conservatively apply one argument at a time, which works because OCaml
-- types every function as unary externally.
function caml_call_gen(f, ...)
  local arity = caml_arity[f]
  local nargs = select("#", ...)
  if arity == nil then
    -- Unknown arity (likely a Lua-side FFI function or a Lua function
    -- without arity info): apply one arg at a time.
    local args = { ... }
    local r = f
    for i = 1, nargs do r = r(args[i]) end
    return r
  end
  if arity == nargs then
    return f(...)
  elseif arity < nargs then
    -- Over-application: call f with its declared arity, then apply rest.
    local args = { ... }
    local r = f(unpack(args, 1, arity))
    for i = arity + 1, nargs do r = caml_call_gen(r, args[i]) end
    return r
  else
    -- Under-application: build a closure that captures these args and
    -- waits for the rest.  Arity decreases by nargs.
    local saved = { ... }
    local rem = arity - nargs
    local partial = function(...)
      local more = { ... }
      local mn = select("#", ...)
      local all = {}
      for i = 1, nargs do all[i] = saved[i] end
      for i = 1, mn do all[nargs + i] = more[i] end
      return f(unpack(all, 1, nargs + mn))
    end
    caml_arity[partial] = rem
    return partial
  end
end
