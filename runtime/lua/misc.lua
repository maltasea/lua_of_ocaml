-- lua_of_ocaml runtime: format, conversion, and misc
-- Provides: caml_format_int caml_format_float caml_int_of_string caml_float_of_string
--           caml_string_of_int caml_int64_float_of_bits caml_int64_bits_of_float
--           caml_sys_exit caml_sys_open caml_input_value caml_output_value
--           caml_atomic_cas_field caml_atomic_load_field caml_atomic_exchange_field
--           caml_atomic_store_field caml_atomic_set_field

local math_floor = math.floor

function caml_format_int(fmt, i)
  return string.format(fmt, math_floor(i / 2))
end

function caml_format_float(fmt, f)
  if type(f) == "table" then return "0.0" end
  return string.format(fmt, f)
end

function caml_int_of_string(s)
  return math_floor(tonumber(s) or 0) * 2
end

function caml_float_of_string(s)
  return { 253, tonumber(s) or 0.0 }
end

function caml_string_of_int(i)
  return tostring(math_floor(i / 2))
end

function caml_int64_float_of_bits(_) return 0 end
function caml_int64_bits_of_float(_) return 0 end

function caml_sys_exit(code) os.exit(math_floor(code / 2)) end
function caml_sys_open(_path, _flags, _perm) return 0 end

function caml_input_value(_chan) return 0 end
function caml_output_value(_chan, _v) return 0 end

-- Aliases for %int_* inline primitives stripped by code generator
int_mul = caml_mul
int_div = caml_div
int_mod = caml_mod

-- FFI demo: user-defined Lua function callable from OCaml via Extern
function lua_add(a, b)
  -- a,b are tagged OCaml ints (value * 2)
  return a + b  -- tagged addition stays tagged
end

function lua_greet(name)
  io.write("hello from Lua: " .. name .. "\n")
  return name
end
os_date = os.date

function caml_atomic_load_field(obj, field_idx)
  local pos = math_floor(field_idx / 2) + 2
  return obj[pos] or 0
end

function caml_atomic_cas_field(obj, field_idx, old_val, new_val, _success)
  local pos = math_floor(field_idx / 2) + 2
  if obj[pos] == old_val then obj[pos] = new_val; return 2 end
  return 0
end

function caml_atomic_exchange_field(obj, field_idx, new_val)
  local pos = math_floor(field_idx / 2) + 2
  local old = obj[pos] or 0; obj[pos] = new_val; return old
end

function caml_atomic_store_field(obj, field_idx, val)
  local pos = math_floor(field_idx / 2) + 2; obj[pos] = val; return 0
end

function caml_atomic_set_field(obj, field_idx, val)
  local pos = math_floor(field_idx / 2) + 2; obj[pos] = val; return 0
end

caml_atomic_load = caml_atomic_load_field
caml_atomic_cas = caml_atomic_cas_field
