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

function caml_sys_executable_name(_) return "" end
function caml_sys_get_config(_) return "" end
function caml_sys_getenv(_) return 0 end
function caml_sys_system(_) return 0 end
function caml_sys_exit(code) os.exit(math_floor(code / 2)) end
function caml_sys_open(_path, _flags, _perm) return 0 end
function caml_sys_file_exists(_) return 0 end
function caml_sys_is_directory(_) return 0 end
function caml_sys_time() return 0 end
function caml_sys_random_seed() return 0 end
function caml_sys_get_argv() return {0} end

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

function caml_atomic_load(obj)
  return obj[2] or 0
end

function caml_atomic_store(obj, val)
  obj[2] = val
  return 0
end

function caml_atomic_exchange(obj, new_val)
  local old = obj[2] or 0
  obj[2] = new_val
  return old
end

function caml_atomic_cas(obj, old_val, new_val)
  if obj[2] == old_val then
    obj[2] = new_val
    return 2
  end
  return 0
end

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

caml_atomic_set = caml_atomic_store

-- Batch stubs for stdlib initialization
caml_sys_const_backend_type = 0
caml_sys_const_big_endian = 0
caml_sys_const_int_size = 0
caml_sys_const_max_wosize = 0
caml_sys_const_ostype_cygwin = 0
caml_sys_const_ostype_unix = 2
caml_sys_const_ostype_win = 0
caml_sys_const_word_size = 0
caml_sys_convert_signal_number = function(_) return 0 end
caml_sys_getenv_opt = function(_) return 0 end
caml_sys_io_buffer_size = function() return 0 end
caml_sys_rev_convert_signal_number = function(_) return 0 end
caml_install_signal_handler = function(_, _) return 0 end
caml_ml_enable_runtime_warnings = function(_) return 0 end
caml_ml_runtime_warnings_enabled = function() return 0 end
caml_atomic_fetch_add_field = function(_, _, _) return 0 end
caml_atomic_make_contended = function(_) return 0 end
caml_compare = function(_, _) return 0 end
caml_array_append = function(_, _) return {0} end
caml_array_blit = function(_, _, _, _, _, _) return 0 end
caml_array_concat = function(_) return {0} end
caml_array_fill = function(_, _, _, _) return 0 end
caml_array_make = function(_, _) return {0} end
caml_array_sub = function(_, _, _) return {0} end
caml_floatarray_get = function(_, _) return 0 end
caml_floatarray_set = function(_, _, _) return 0 end
caml_ephe_create = function(_, _) return {0} end
caml_ephe_blit_data = function(_, _, _, _, _, _) return 0 end
caml_ephe_blit_key = function(_, _, _, _, _, _) return 0 end
caml_ephe_check_data = function(_, _) return 0 end
caml_ephe_check_key = function(_, _) return 0 end
caml_ephe_get_data = function(_, _) return {0} end
caml_ephe_get_data_copy = function(_, _) return {0} end
caml_ephe_get_key = function(_, _) return {0} end
caml_ephe_get_key_copy = function(_, _) return {0} end
caml_ephe_set_data = function(_, _, _) return 0 end
caml_ephe_set_key = function(_, _, _) return 0 end
caml_ephe_unset_data = function(_, _, _) return 0 end
caml_ephe_unset_key = function(_, _, _) return 0 end
caml_lazy_make_forward = function(_) return 0 end
caml_lazy_reset_to_lazy = function(_) return 0 end
caml_lazy_update_to_forcing = function(_) return 0 end
caml_lazy_update_to_forward = function(_) return 0 end
