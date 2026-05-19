-- lua_of_ocaml runtime: standard library (globals, call support)
-- Provides: caml_register_global caml_register_named_value caml_get_global
--           caml_fresh_oo_id caml_call_gen caml_set_global caml_bind_frame
--           caml_equal caml_notequal

local math_floor = math.floor

caml_global_data = {}

function caml_equal(a, b) return a == b end
function caml_notequal(a, b) return a ~= b end

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
