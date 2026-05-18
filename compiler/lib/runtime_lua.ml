(** OCaml runtime in Lua 5.1, embedded as strings. *)

let preamble = {|
-- lua_of_ocaml runtime (Lua 5.1)
local math_floor = math.floor
local math_ceil = math.ceil
local math_abs = math.abs

-- Global data table for OCaml compilation units
caml_global_data = {}

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

-- OO support (stub)
caml_oo_last_id = 0
function caml_fresh_oo_id(_)
  caml_oo_last_id = caml_oo_last_id + 1
  return caml_oo_last_id * 2
end

---- Integer arithmetic (tagged: ocaml_int * 2) ----
-- For add/sub: both operands already shifted, result remains shifted
-- For mul: (2a * 2b) / 2 = 2ab  (overflows easily in float, but OK for small ints)
-- For div: (2a/2) / (2b/2) * 2 = 2*(a/b)

function caml_mul(a, b) return math_floor(a * b / 2) end
function caml_div(a, b) return math_floor(math_floor(a / 2) / math_floor(b / 2)) * 2 end
function caml_mod(a, b)
  local a2 = math_floor(a / 2)
  local b2 = math_floor(b / 2)
  local m = a2 % b2
  if m < 0 then m = m + b2 end return m * 2
end

-- Helper: pure-Lua bitwise AND for 32-bit integers (Lua 5.1 compat)
local function uint_and(a, b)
  local r = 0; local w = 1
  for i = 0, 31 do
    if (a % 2 > 0) and (b % 2 > 0) then r = r + w end
    a = math_floor(a / 2); b = math_floor(b / 2); w = w * 2
  end
  return r
end
local function uint_or(a, b)
  local r = 0; local w = 1
  for i = 0, 31 do
    if (a % 2 > 0) or (b % 2 > 0) then r = r + w end
    a = math_floor(a / 2); b = math_floor(b / 2); w = w * 2
  end
  return r
end
local function uint_xor(a, b)
  local r = 0; local w = 1
  for i = 0, 31 do
    if ((a % 2 > 0) and (b % 2 == 0)) or ((a % 2 == 0) and (b % 2 > 0)) then r = r + w end
    a = math_floor(a / 2); b = math_floor(b / 2); w = w * 2
  end
  return r
end
local function uint_shl(a, b)
  if b >= 32 then return 0 end
  return (a * (2 ^ b)) % (2 ^ 32)
end
local function uint_shr(a, b)
  if b >= 32 then return 0 end
  return math_floor(a / (2 ^ b))
end

-- Bitwise ops on tagged ints (untag, operate, retag)
function int_and(a, b) return uint_and(math_floor(a/2), math_floor(b/2)) * 2 end
function int_or(a, b)  return uint_or(math_floor(a/2), math_floor(b/2)) * 2 end
function int_xor(a, b) return uint_xor(math_floor(a/2), math_floor(b/2)) * 2 end
function int_lsl(a, b) return uint_shl(math_floor(a/2), math_floor(b/2)) * 2 end
function int_lsr(a, b) return uint_shr(math_floor(a/2), math_floor(b/2)) * 2 end
function int_asr(a, b)
  local a2 = math_floor(a / 2); local b2 = math_floor(b / 2)
  if a2 >= 2^31 then a2 = a2 - 2^32 end  -- sign extend
  return math_floor(a2 / (2 ^ b2)) * 2
end
function int_add(a, b) return a + b end
function int_sub(a, b) return a - b end
function int_neg(a) return -a end

-- Aliases
caml_and = int_and; caml_or = int_or; caml_xor = int_xor
caml_lsl = int_lsl; caml_lsr = int_lsr; caml_asr = int_asr

-- Comparisons on tagged ints
function caml_eq(a, b) return a == b end
function caml_neq(a, b) return a ~= b end
function caml_lt(a, b) return a < b end
function caml_le(a, b) return a <= b end
function caml_gt(a, b) return a > b end
function caml_ge(a, b) return a >= b end
function caml_lessequal(a, b) return a <= b end
function caml_greaterequal(a, b) return a >= b end
function caml_lessthan(a, b) return a < b end
function caml_greaterthan(a, b) return a > b end

-- Not / IsInt
function caml_not(x) return (x == 0) and 2 or 0 end
function caml_is_int(x) return type(x) == "number" end

---- Block operations ----
function caml_obj_tag(b)
  if type(b) == "table" then return b[1] or 0 else return 0 end
end
function caml_obj_block(tag, ...)
  local b = { tag }
  for i = 1, select("#", ...) do b[i + 1] = select(i, ...) end
  return b
end
function caml_obj_dup(b)
  local n = { b[1] }
  for i = 2, #b do n[i] = b[i] end
  return n
end
function caml_obj_set_raw_field(b, i, v) b[i + 2] = v end

---- Exception support ----
function caml_failwith(msg) error(msg) end
function caml_invalid_argument(msg) error("Invalid_argument: " .. msg) end
function caml_raise(exn)
  -- MVP: silently exit via sentinel
  return 0
end

---- String operations ----
-- OCaml strings are Lua strings. Length is NOT tagged.
function caml_string_length(s) return #s end
function caml_ml_string_length(s)
  if s == nil then return 0 end
  return #s
end

function caml_string_length(s)
  if s == nil then return 0 end
  return #s
end
function caml_string_get(s, i) return string.byte(s, math_floor(i/2) + 1) * 2 end
function caml_create_string(len) return string.rep("\0", math_floor(len/2)) end
function caml_create_bytes(len) return string.rep("\0", math_floor(len/2)) end
function caml_ml_bytes_length(b) return #b end

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
function caml_bytes_compare(a, b) return caml_string_compare(a, b) end

function caml_string_concat(a, b) return a .. b end
function caml_string_of_bytes(s) return s end
function caml_bytes_of_string(s) return s end

---- String/number conversion ----
function caml_format_int(fmt, i)
  return string.format(fmt, math_floor(i / 2))
end

function caml_format_float(fmt, f)
  -- f is a boxed float (table with tag 253)
  -- For now, just return "0.0"
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

-- Int64 stubs
function caml_int64_float_of_bits(_) return 0 end
function caml_int64_bits_of_float(_) return 0 end

---- Channel I/O ----
caml_ml_out_channels_list = function() return { 0, 0, 0 } end

function caml_ml_open_descriptor_in(fd) return fd end
function caml_ml_open_descriptor_out(fd) return fd end

function caml_ml_output(chan, s, ofs, len)
  if s == nil then return 0 end
  local o = math_floor(ofs / 2) + 1
  local l = math_floor(len / 2)
  local ss = string.sub(s, o, o + l - 1)
  io.write(ss)
  return 0
end

function caml_ml_output_bytes(chan, b, ofs, len)
  return caml_ml_output(chan, b, ofs, len)
end

function caml_ml_output_char(chan, c)
  local ch = string.char(math_floor(c / 2))
  io.write(ch)
  return 0
end

function caml_ml_output_int(chan, i)
  local s = tostring(math_floor(i / 2))
  io.write(s)
  return 0
end

function caml_ml_flush(_chan) io.flush(); return 0 end

function caml_ml_input_char(chan)
  local c = io.read(1)
  if c == nil then return 0 end
  return string.byte(c) * 2  -- return tagged int EOF marker for actual EOF
end

function caml_ml_input(chan, s, ofs, len)
  local o = math_floor(ofs / 2) + 1
  local l = math_floor(len / 2)
  local data = io.read(l)
  if data == nil then return 0 end
  return caml_blit_string(data, 0, s, ofs, #data * 2)
end

function caml_ml_input_int(chan)
  local n = tonumber(io.read("*n"))
  if n == nil then return 0 end
  return n * 2
end

function caml_ml_input_scan_line(chan)
  local line = io.read("*l")
  if line == nil then return 0 end
  return line
end

-- Channel position/size stubs
function caml_ml_channel_size(_chan) return 0 end
function caml_ml_channel_size_64(_chan) return 0 end
function caml_ml_pos_in(_chan) return 0 end
function caml_ml_pos_in_64(_chan) return 0 end
function caml_ml_pos_out(_chan) return 0 end
function caml_ml_pos_out_64(_chan) return 0 end
function caml_ml_seek_in(_chan, _pos) return 0 end
function caml_ml_seek_in_64(_chan, _pos) return 0 end
function caml_ml_seek_out(_chan, _pos) return 0 end
function caml_ml_seek_out_64(_chan, _pos) return 0 end
function caml_ml_set_binary_mode(_chan, _mode) return 0 end
function caml_ml_set_channel_name(_chan, _name) return 0 end
function caml_ml_close_channel(_chan) return 0 end

-- Sys stubs
function caml_sys_exit(code) os.exit(math_floor(code / 2)) end
function caml_sys_open(_path, _flags, _perm) return 0 end

---- Atomic operations (field access on OCaml blocks) ----
-- OCaml blocks: Lua table {tag, field0, field1, ...}
-- field index n (tagged int) → position n/2 + 2 in the Lua table

function caml_atomic_load_field(obj, field_idx)
  local pos = math_floor(field_idx / 2) + 2
  return obj[pos] or 0
end

function caml_atomic_cas_field(obj, field_idx, old_val, new_val, _success)
  local pos = math_floor(field_idx / 2) + 2
  if obj[pos] == old_val then
    obj[pos] = new_val
    return 2  -- true (tagged)
  end
  return 0  -- false
end

function caml_atomic_exchange_field(obj, field_idx, new_val)
  local pos = math_floor(field_idx / 2) + 2
  local old = obj[pos] or 0
  obj[pos] = new_val
  return old
end

function caml_atomic_store_field(obj, field_idx, val)
  local pos = math_floor(field_idx / 2) + 2
  obj[pos] = val
  return 0
end

function caml_atomic_set_field(obj, field_idx, val)
  local pos = math_floor(field_idx / 2) + 2
  obj[pos] = val
  return 0
end

---- Marshal stubs ----
function caml_input_value(_chan) return 0 end
function caml_output_value(_chan, _v) return 0 end

---- Vector operations ----
function caml_vect_length(v) return (#v - 1) * 2 end
function caml_array_get(v, i) return v[math_floor(i / 2) + 2] or 0 end
function caml_array_set(v, i, x) v[math_floor(i / 2) + 2] = x; return 0 end
function caml_array_unsafe_get(v, i) return caml_array_get(v, i) end
function caml_array_unsafe_set(v, i, x) return caml_array_set(v, i, x) end

---- Call support ----
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

---- Exception frame binding ----
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

---- Misc ----
|}

let postamble = {|
-- Entry point
local ok, err = pcall(_main)
if not ok then io.stderr:write("ERROR: " .. tostring(err) .. "\n") end
|}
