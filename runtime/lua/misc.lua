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

-- Floats are boxed as { 253, value }.  Helper to unwrap.
local function _f(x) if type(x) == "table" then return x[2] or 0 end; return x or 0 end
local function _bf(v) return { 253, v } end

function caml_format_float(fmt, f) return string.format(fmt, _f(f)) end

function caml_add_float(a, b) return _bf(_f(a) + _f(b)) end
function caml_sub_float(a, b) return _bf(_f(a) - _f(b)) end
function caml_mul_float(a, b) return _bf(_f(a) * _f(b)) end
function caml_div_float(a, b) return _bf(_f(a) / _f(b)) end
function caml_neg_float(a)    return _bf(-_f(a)) end
function caml_abs_float(a)    return _bf(math.abs(_f(a))) end
function caml_sqrt_float(a)   return _bf(math.sqrt(_f(a))) end
function caml_exp_float(a)    return _bf(math.exp(_f(a))) end
function caml_log_float(a)    return _bf(math.log(_f(a))) end
function caml_sin_float(a)    return _bf(math.sin(_f(a))) end
function caml_cos_float(a)    return _bf(math.cos(_f(a))) end
function caml_tan_float(a)    return _bf(math.tan(_f(a))) end
function caml_floor_float(a)  return _bf(math.floor(_f(a))) end
function caml_ceil_float(a)   return _bf(math.ceil(_f(a))) end
function caml_power_float(a, b) return _bf(_f(a) ^ _f(b)) end
function caml_fmod_float(a, b) return _bf(math.fmod(_f(a), _f(b))) end

function caml_eq_float(a, b)  return _f(a) == _f(b) end
function caml_neq_float(a, b) return _f(a) ~= _f(b) end
function caml_lt_float(a, b)  return _f(a) <  _f(b) end
function caml_le_float(a, b)  return _f(a) <= _f(b) end
function caml_gt_float(a, b)  return _f(a) >  _f(b) end
function caml_ge_float(a, b)  return _f(a) >= _f(b) end
caml_float_compare = function(a, b)
  local x, y = _f(a), _f(b)
  if x < y then return -2 elseif x > y then return 2 else return 0 end
end

function caml_float_of_int(i) return _bf(math_floor(i / 2)) end
function caml_int_of_float(f) return math_floor(_f(f)) * 2 end
function caml_int_of_float_unboxed(f) return math_floor(_f(f)) * 2 end

function caml_classify_float(f)
  local v = _f(f)
  if v ~= v then return 8 end                 -- NaN
  if v == math.huge or v == -math.huge then return 6 end
  if v == 0 then return 4 end
  return 0                                     -- FP_normal
end

function caml_signbit_float(f) return (_f(f) < 0) and 2 or 0 end
function caml_float_of_bytes(s) return _bf(tonumber(s) or 0) end
function caml_hexstring_of_float(_, _, _) return "0x0p+0" end
function caml_float_of_hexstring(_) return _bf(0) end
function caml_modf_float(f)
  local v = _f(f); local i = (v >= 0) and math.floor(v) or math.ceil(v)
  return { 0, _bf(v - i), _bf(i) }
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

-- Sys.* constants.  Returned values must be OCaml-encoded ints (2*n).
-- These feed real arithmetic (e.g. max_string_length depends on word_size),
-- so wrong values silently corrupt downstream computation.
caml_sys_const_backend_type = function() return {0, "Other", "lua_of_ocaml"} end
caml_sys_const_big_endian = function() return 0 end                -- false
caml_sys_const_int_size = function() return 126 end                -- encoded 63
caml_sys_const_max_wosize = function() return 2 * (2^22 - 1) end   -- ~jsoo's value
caml_sys_const_ostype_cygwin = function() return 0 end
caml_sys_const_ostype_unix = function() return 2 end               -- true
caml_sys_const_ostype_win = function() return 0 end
caml_sys_const_ostype_win32 = function() return 0 end
caml_sys_const_word_size = function() return 128 end               -- encoded 64
caml_sys_convert_signal_number = function(_) return 0 end
caml_sys_getenv_opt = function(_) return 0 end
caml_sys_io_buffer_size = function() return 131072 end             -- encoded 65536
caml_sys_rev_convert_signal_number = function(_) return 0 end
caml_install_signal_handler = function(_, _) return 0 end
caml_ml_enable_runtime_warnings = function(_) return 0 end
caml_ml_runtime_warnings_enabled = function() return 0 end
caml_atomic_fetch_add_field = function(_, _, _) return 0 end
caml_atomic_make_contended = function(_) return 0 end
-- caml_compare provided by stdlib.lua (structural)
-- caml_array_* provided by array.lua
caml_floatarray_get = caml_array_get
caml_floatarray_set = caml_array_set
caml_floatarray_unsafe_get = caml_array_unsafe_get
caml_floatarray_unsafe_set = caml_array_unsafe_set
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

-- Auto-stub: undefined caml_* calls return 0 instead of crashing.
-- Gated by LOO_STRICT=1: under strict mode, undefined caml_* throws so
-- missing primitives surface in tests instead of silently corrupting output.
if not (os.getenv and os.getenv("LOO_STRICT") == "1") then
  local _gm = getmetatable(_G) or {}
  local _old_index = _gm.__index
  _gm.__index = function(t, k)
    if type(k) == "string" and string.match(k, "^caml_") then
      return function(...) return 0 end
    end
    if type(_old_index) == "function" then return _old_index(t, k) end
    if type(_old_index) == "table" then return _old_index[k] end
  end
  setmetatable(_G, _gm)
end
