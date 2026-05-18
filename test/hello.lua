
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
  if s == nil then io.stderr:write("[nil len="..tostring(len).."]\n"); return 0 end
  local o = math_floor(ofs / 2) + 1
  local l = math_floor(len / 2)
  local ss = string.sub(s, o, o + l - 1)
  io.stderr:write("[OUT:'" .. ss .. "']\n")
  io.write(ss)
  return 0
end

function caml_ml_output_bytes(chan, b, ofs, len)
  return caml_ml_output(chan, b, ofs, len)
end

function caml_ml_output_char(chan, c)
  io.write(string.char(math_floor(c / 2)))
  return 0
end

function caml_ml_output_int(chan, i)
  io.write(tostring(math_floor(i / 2)))
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

---- Misc ----
-- caml_ml_output is a function, not a channel variable

_block_0 = nil
_block_97 = nil
_block_1 = nil
_block_2 = nil
_block_4 = nil
_block_3 = nil
_block_5 = nil
_block_6 = nil
_block_7 = nil
_block_8 = nil
_block_9 = nil
_block_10 = nil
_block_11 = nil
_block_12 = nil
_block_13 = nil
_block_14 = nil
_block_15 = nil
_block_16 = nil
_block_17 = nil
_block_18 = nil
_block_19 = nil
_block_20 = nil
_block_21 = nil
_block_23 = nil
_block_22 = nil
_block_24 = nil
_block_25 = nil
_block_26 = nil
_block_27 = nil
_block_28 = nil
_block_29 = nil
_block_30 = nil
_block_31 = nil
_block_32 = nil
_block_33 = nil
_block_34 = nil
_block_35 = nil
_block_36 = nil
_block_37 = nil
_block_38 = nil
_block_39 = nil
_block_40 = nil
_block_42 = nil
_block_41 = nil
_block_43 = nil
_block_44 = nil
_block_45 = nil
_block_46 = nil
_block_47 = nil
_block_48 = nil
_block_49 = nil
_block_50 = nil
_block_51 = nil
_block_52 = nil
_block_53 = nil
_block_54 = nil
_block_55 = nil
_block_56 = nil
_block_57 = nil
_block_58 = nil
_block_59 = nil
_block_60 = nil
_block_61 = nil
_block_62 = nil
_block_63 = nil
_block_64 = nil
_block_65 = nil
_block_66 = nil
_block_67 = nil
_block_68 = nil
_block_69 = nil
_block_71 = nil
_block_70 = nil
_block_72 = nil
_block_73 = nil
_block_74 = nil
_block_75 = nil
_block_76 = nil
_block_77 = nil
_block_78 = nil
_block_79 = nil
_block_80 = nil
_block_81 = nil
_block_82 = nil
_block_83 = nil
_block_84 = nil
_block_85 = nil
_block_86 = nil
_block_87 = nil
_block_88 = nil
_block_89 = nil
_block_90 = nil
_block_91 = nil
_block_92 = nil
_block_93 = nil
_block_94 = nil
_block_95 = nil
_block_96 = nil
_block_297 = nil
_block_296 = nil
_block_295 = nil
_block_292 = nil
_block_293 = nil
_block_294 = nil
_block_289 = nil
_block_290 = nil
_block_291 = nil
_block_286 = nil
_block_287 = nil
_block_288 = nil
_block_285 = nil
_block_284 = nil
_block_280 = nil
_block_281 = nil
_block_282 = nil
_block_283 = nil
_block_277 = nil
_block_278 = nil
_block_279 = nil
_block_272 = nil
_block_273 = nil
_block_276 = nil
_block_274 = nil
_block_275 = nil
_block_267 = nil
_block_268 = nil
_block_271 = nil
_block_269 = nil
_block_270 = nil
_block_266 = nil
_block_259 = nil
_block_260 = nil
_block_261 = nil
_block_263 = nil
_block_264 = nil
_block_265 = nil
_block_258 = nil
_block_249 = nil
_block_250 = nil
_block_251 = nil
_block_252 = nil
_block_256 = nil
_block_253 = nil
_block_257 = nil
_block_254 = nil
_block_255 = nil
_block_248 = nil
_block_241 = nil
_block_242 = nil
_block_243 = nil
_block_245 = nil
_block_246 = nil
_block_247 = nil
_block_98 = nil
_block_99 = nil
_block_100 = nil
_block_101 = nil
_block_102 = nil
_block_103 = nil
_block_104 = nil
_block_105 = nil
_block_106 = nil
_block_107 = nil
_block_108 = nil
_block_109 = nil
_block_110 = nil
_block_111 = nil
_block_240 = nil
_block_239 = nil
_block_238 = nil
_block_237 = nil
_block_226 = nil
_block_227 = nil
_block_228 = nil
_block_229 = nil
_block_231 = nil
_block_232 = nil
_block_234 = nil
_block_235 = nil
_block_233 = nil
_block_236 = nil
_block_225 = nil
_block_224 = nil
_block_219 = nil
_block_220 = nil
_block_221 = nil
_block_222 = nil
_block_223 = nil
_block_214 = nil
_block_215 = nil
_block_216 = nil
_block_217 = nil
_block_218 = nil
_block_213 = nil
_block_212 = nil
_block_202 = nil
_block_203 = nil
_block_204 = nil
_block_206 = nil
_block_207 = nil
_block_208 = nil
_block_209 = nil
_block_211 = nil
_block_201 = nil
_block_200 = nil
_block_199 = nil
_block_194 = nil
_block_195 = nil
_block_196 = nil
_block_197 = nil
_block_198 = nil
_block_112 = nil
_block_114 = nil
_block_115 = nil
_block_116 = nil
_block_113 = nil
_block_189 = nil
_block_190 = nil
_block_191 = nil
_block_192 = nil
_block_193 = nil
_block_188 = nil
_block_187 = nil
_block_175 = nil
_block_176 = nil
_block_177 = nil
_block_178 = nil
_block_179 = nil
_block_180 = nil
_block_181 = nil
_block_182 = nil
_block_183 = nil
_block_184 = nil
_block_185 = nil
_block_186 = nil
_block_170 = nil
_block_171 = nil
_block_172 = nil
_block_174 = nil
_block_169 = nil
_block_168 = nil
_block_167 = nil
_block_166 = nil
_block_165 = nil
_block_164 = nil
_block_163 = nil
_block_162 = nil
_block_161 = nil
_block_160 = nil
_block_159 = nil
_block_158 = nil
_block_157 = nil
_block_156 = nil
_block_155 = nil
_block_154 = nil
_block_153 = nil
_block_152 = nil
_block_151 = nil
_block_150 = nil
_block_149 = nil
_block_120 = nil
_block_117 = nil
_block_118 = nil
_block_119 = nil
_block_121 = nil
_block_122 = nil
_block_148 = nil
_block_147 = nil
_block_146 = nil
_block_145 = nil
_block_144 = nil
_block_143 = nil
_block_142 = nil
_block_141 = nil
_block_140 = nil
_block_139 = nil
_block_138 = nil
_block_137 = nil
_block_136 = nil
_block_135 = nil
_block_134 = nil
_block_133 = nil
_block_132 = nil
_block_131 = nil
_block_130 = nil
_block_129 = nil
_block_128 = nil
_block_127 = nil
_block_126 = nil
_block_125 = nil
_block_124 = nil
_block_123 = nil
_block_0 = function() Out_of_memory_359 = {248, "Out_of_memory", -2}
Sys_error_361 = {248, "Sys_error", -4}
Failure_347 = {248, "Failure", -6}
Invalid_argument_341 = {248, "Invalid_argument", -8}
End_of_file_362 = {248, "End_of_file", -10}
Division_by_zero_363 = {248, "Division_by_zero", -12}
Not_found_358 = {248, "Not_found", -14}
Match_failure_356 = {248, "Match_failure", -16}
Stack_overflow_360 = {248, "Stack_overflow", -18}
Sys_blocked_io_364 = {248, "Sys_blocked_io", -20}
Assert_failure_357 = {248, "Assert_failure", -22}
Undefined_recursive_module_365 = {248, "Undefined_recursive_module", -24}
_v872 = "%,"
_v714 = "really_input"
_v684 = "input"
_v667 = {0, 0, {0, 12, 0}}
_v662 = {0, 0, {0, 14, 0}}
_v627 = "output_substring"
_v609 = "output"
_v556 = {0, 2, {0, 6, {0, 8, {0, 12, 0}}}}
_v551 = {0, 2, {0, 6, {0, 8, {0, 14, 0}}}}
_v481 = "%.12g"
_v462 = "."
_v445 = "%d"
_v436 = "false"
_v438 = "true"
_v441 = {0, 2}
_v442 = {0, 0}
_v426 = "false"
_v428 = "true"
_v430 = "bool_of_string"
_v422 = "true"
_v423 = "false"
_v418 = "char_of_int"
_v340 = "index out of bounds"
_v343 = "Pervasives.array_bound_error"
_v354 = "Stdlib.Exit"
_v387 = 0
_v389 = 0
_v391 = 0
_v393 = 0
_v395 = 0
_v397 = 0
_v919 = "Pervasives.do_at_exit"
_v1002 = "x"
_v1023 = caml_register_global(22, Undefined_recursive_module_365, "")
_v1022 = caml_register_global(20, Assert_failure_357, "")
_v1021 = caml_register_global(18, Sys_blocked_io_364, "")
_v1020 = caml_register_global(16, Stack_overflow_360, "")
_v1019 = caml_register_global(14, Match_failure_356, "")
_v1018 = caml_register_global(12, Not_found_358, "")
_v1017 = caml_register_global(10, Division_by_zero_363, "")
_v1016 = caml_register_global(8, End_of_file_362, "")
_v1015 = caml_register_global(6, Invalid_argument_341, "")
_v1014 = caml_register_global(4, Failure_347, "")
_v1013 = caml_register_global(2, Sys_error_361, "")
_v1012 = caml_register_global(0, Out_of_memory_359, "")
return _block_97()
end
_block_97 = function() _v1 = function(_v2) return _block_1(_v2)
end
_v53 = function(_v55, _v54) return _block_20(_v55, _v54)
end
_v106 = function(_v108, _v107) return _block_39(_v108, _v107)
end
_v218 = function(_v220, _v219) return _block_68(_v220, _v219)
end
_v337 = {0, _v53, _v1, _v106, _v218}
_v338 = 0
return _block_297()
end
_block_1 = function() _v52 = type(_v2) == "number"
if _v52 then return _block_2()
 else return _block_3()
 end
end
_block_2 = function() if _v2 == 0 then return _block_4()
 end
end
_block_4 = function() _v3 = 0
return _v3
end
_block_3 = function() _v51 = direct_obj_tag(_v2)
if _v51 == 0 then return _block_5()
 else if _v51 == 1 then return _block_6()
 else if _v51 == 2 then return _block_7()
 else if _v51 == 3 then return _block_8()
 else if _v51 == 4 then return _block_9()
 else if _v51 == 5 then return _block_10()
 else if _v51 == 6 then return _block_11()
 else if _v51 == 7 then return _block_12()
 else if _v51 == 8 then return _block_13()
 else if _v51 == 9 then return _block_14()
 else if _v51 == 10 then return _block_15()
 else if _v51 == 11 then return _block_16()
 else if _v51 == 12 then return _block_17()
 else if _v51 == 13 then return _block_18()
 else if _v51 == 14 then return _block_19()
 end
 end
 end
 end
 end
 end
 end
 end
 end
 end
 end
 end
 end
 end
 end
end
_block_5 = function() _v4 = _v2[2]
_v5 = _v1(_v4)
_v6 = {0, _v5}
return _v6
end
_block_6 = function() _v7 = _v2[2]
_v8 = _v1(_v7)
_v9 = {1, _v8}
return _v9
end
_block_7 = function() _v10 = _v2[2]
_v11 = _v1(_v10)
_v12 = {2, _v11}
return _v12
end
_block_8 = function() _v13 = _v2[2]
_v14 = _v1(_v13)
_v15 = {3, _v14}
return _v15
end
_block_9 = function() _v16 = _v2[2]
_v17 = _v1(_v16)
_v18 = {4, _v17}
return _v18
end
_block_10 = function() _v19 = _v2[2]
_v20 = _v1(_v19)
_v21 = {5, _v20}
return _v21
end
_block_11 = function() _v22 = _v2[2]
_v23 = _v1(_v22)
_v24 = {6, _v23}
return _v24
end
_block_12 = function() _v25 = _v2[2]
_v26 = _v1(_v25)
_v27 = {7, _v26}
return _v27
end
_block_13 = function() _v28 = _v2[3]
_v29 = _v2[2]
_v30 = _v1(_v28)
_v31 = {8, _v29, _v30}
return _v31
end
_block_14 = function() _v32 = _v2[4]
_v33 = _v2[2]
_v34 = _v1(_v32)
_v35 = {9, _v33, _v33, _v34}
return _v35
end
_block_15 = function() _v36 = _v2[2]
_v37 = _v1(_v36)
_v38 = {10, _v37}
return _v38
end
_block_16 = function() _v39 = _v2[2]
_v40 = _v1(_v39)
_v41 = {11, _v40}
return _v41
end
_block_17 = function() _v42 = _v2[2]
_v43 = _v1(_v42)
_v44 = {12, _v43}
return _v44
end
_block_18 = function() _v45 = _v2[2]
_v46 = _v1(_v45)
_v47 = {13, _v46}
return _v47
end
_block_19 = function() _v48 = _v2[2]
_v49 = _v1(_v48)
_v50 = {14, _v49}
return _v50
end
_block_20 = function() _v105 = type(_v55) == "number"
if _v105 then return _block_21()
 else return _block_22()
 end
end
_block_21 = function() if _v55 == 0 then return _block_23()
 end
end
_block_23 = function() return _v54
end
_block_22 = function() _v104 = direct_obj_tag(_v55)
if _v104 == 0 then return _block_24()
 else if _v104 == 1 then return _block_25()
 else if _v104 == 2 then return _block_26()
 else if _v104 == 3 then return _block_27()
 else if _v104 == 4 then return _block_28()
 else if _v104 == 5 then return _block_29()
 else if _v104 == 6 then return _block_30()
 else if _v104 == 7 then return _block_31()
 else if _v104 == 8 then return _block_32()
 else if _v104 == 9 then return _block_33()
 else if _v104 == 10 then return _block_34()
 else if _v104 == 11 then return _block_35()
 else if _v104 == 12 then return _block_36()
 else if _v104 == 13 then return _block_37()
 else if _v104 == 14 then return _block_38()
 end
 end
 end
 end
 end
 end
 end
 end
 end
 end
 end
 end
 end
 end
 end
end
_block_24 = function() _v56 = _v55[2]
_v57 = _v53(_v56, _v54)
_v58 = {0, _v57}
return _v58
end
_block_25 = function() _v59 = _v55[2]
_v60 = _v53(_v59, _v54)
_v61 = {1, _v60}
return _v61
end
_block_26 = function() _v62 = _v55[2]
_v63 = _v53(_v62, _v54)
_v64 = {2, _v63}
return _v64
end
_block_27 = function() _v65 = _v55[2]
_v66 = _v53(_v65, _v54)
_v67 = {3, _v66}
return _v67
end
_block_28 = function() _v68 = _v55[2]
_v69 = _v53(_v68, _v54)
_v70 = {4, _v69}
return _v70
end
_block_29 = function() _v71 = _v55[2]
_v72 = _v53(_v71, _v54)
_v73 = {5, _v72}
return _v73
end
_block_30 = function() _v74 = _v55[2]
_v75 = _v53(_v74, _v54)
_v76 = {6, _v75}
return _v76
end
_block_31 = function() _v77 = _v55[2]
_v78 = _v53(_v77, _v54)
_v79 = {7, _v78}
return _v79
end
_block_32 = function() _v80 = _v55[3]
_v81 = _v55[2]
_v82 = _v53(_v80, _v54)
_v83 = {8, _v81, _v82}
return _v83
end
_block_33 = function() _v84 = _v55[4]
_v85 = _v55[3]
_v86 = _v55[2]
_v87 = _v53(_v84, _v54)
_v88 = {9, _v86, _v85, _v87}
return _v88
end
_block_34 = function() _v89 = _v55[2]
_v90 = _v53(_v89, _v54)
_v91 = {10, _v90}
return _v91
end
_block_35 = function() _v92 = _v55[2]
_v93 = _v53(_v92, _v54)
_v94 = {11, _v93}
return _v94
end
_block_36 = function() _v95 = _v55[2]
_v96 = _v53(_v95, _v54)
_v97 = {12, _v96}
return _v97
end
_block_37 = function() _v98 = _v55[2]
_v99 = _v53(_v98, _v54)
_v100 = {13, _v99}
return _v100
end
_block_38 = function() _v101 = _v55[2]
_v102 = _v53(_v101, _v54)
_v103 = {14, _v102}
return _v103
end
_block_39 = function() _v217 = type(_v108) == "number"
if _v217 then return _block_40()
 else return _block_41()
 end
end
_block_40 = function() if _v108 == 0 then return _block_42()
 end
end
_block_42 = function() return _v107
end
_block_41 = function() _v216 = direct_obj_tag(_v108)
if _v216 == 0 then return _block_43()
 else if _v216 == 1 then return _block_44()
 else if _v216 == 2 then return _block_45()
 else if _v216 == 3 then return _block_46()
 else if _v216 == 4 then return _block_47()
 else if _v216 == 5 then return _block_48()
 else if _v216 == 6 then return _block_49()
 else if _v216 == 7 then return _block_50()
 else if _v216 == 8 then return _block_51()
 else if _v216 == 9 then return _block_52()
 else if _v216 == 10 then return _block_53()
 else if _v216 == 11 then return _block_54()
 else if _v216 == 12 then return _block_55()
 else if _v216 == 13 then return _block_56()
 else if _v216 == 14 then return _block_57()
 else if _v216 == 15 then return _block_58()
 else if _v216 == 16 then return _block_59()
 else if _v216 == 17 then return _block_60()
 else if _v216 == 18 then return _block_61()
 else if _v216 == 19 then return _block_62()
 else if _v216 == 20 then return _block_63()
 else if _v216 == 21 then return _block_64()
 else if _v216 == 22 then return _block_65()
 else if _v216 == 23 then return _block_66()
 else if _v216 == 24 then return _block_67()
 end
 end
 end
 end
 end
 end
 end
 end
 end
 end
 end
 end
 end
 end
 end
 end
 end
 end
 end
 end
 end
 end
 end
 end
 end
end
_block_43 = function() _v109 = _v108[2]
_v110 = _v106(_v109, _v107)
_v111 = {0, _v110}
return _v111
end
_block_44 = function() _v112 = _v108[2]
_v113 = _v106(_v112, _v107)
_v114 = {1, _v113}
return _v114
end
_block_45 = function() _v115 = _v108[3]
_v116 = _v108[2]
_v117 = _v106(_v115, _v107)
_v118 = {2, _v116, _v117}
return _v118
end
_block_46 = function() _v119 = _v108[3]
_v120 = _v108[2]
_v121 = _v106(_v119, _v107)
_v122 = {3, _v120, _v121}
return _v122
end
_block_47 = function() _v123 = _v108[5]
_v124 = _v108[4]
_v125 = _v108[3]
_v126 = _v108[2]
_v127 = _v106(_v123, _v107)
_v128 = {4, _v126, _v125, _v124, _v127}
return _v128
end
_block_48 = function() _v129 = _v108[5]
_v130 = _v108[4]
_v131 = _v108[3]
_v132 = _v108[2]
_v133 = _v106(_v129, _v107)
_v134 = {5, _v132, _v131, _v130, _v133}
return _v134
end
_block_49 = function() _v135 = _v108[5]
_v136 = _v108[4]
_v137 = _v108[3]
_v138 = _v108[2]
_v139 = _v106(_v135, _v107)
_v140 = {6, _v138, _v137, _v136, _v139}
return _v140
end
_block_50 = function() _v141 = _v108[5]
_v142 = _v108[4]
_v143 = _v108[3]
_v144 = _v108[2]
_v145 = _v106(_v141, _v107)
_v146 = {7, _v144, _v143, _v142, _v145}
return _v146
end
_block_51 = function() _v147 = _v108[5]
_v148 = _v108[4]
_v149 = _v108[3]
_v150 = _v108[2]
_v151 = _v106(_v147, _v107)
_v152 = {8, _v150, _v149, _v148, _v151}
return _v152
end
_block_52 = function() _v153 = _v108[3]
_v154 = _v108[2]
_v155 = _v106(_v153, _v107)
_v156 = {9, _v154, _v155}
return _v156
end
_block_53 = function() _v157 = _v108[2]
_v158 = _v106(_v157, _v107)
_v159 = {10, _v158}
return _v159
end
_block_54 = function() _v160 = _v108[3]
_v161 = _v108[2]
_v162 = _v106(_v160, _v107)
_v163 = {11, _v161, _v162}
return _v163
end
_block_55 = function() _v164 = _v108[3]
_v165 = _v108[2]
_v166 = _v106(_v164, _v107)
_v167 = {12, _v165, _v166}
return _v167
end
_block_56 = function() _v168 = _v108[4]
_v169 = _v108[3]
_v170 = _v108[2]
_v171 = _v106(_v168, _v107)
_v172 = {13, _v170, _v169, _v171}
return _v172
end
_block_57 = function() _v173 = _v108[4]
_v174 = _v108[3]
_v175 = _v108[2]
_v176 = _v106(_v173, _v107)
_v177 = {14, _v175, _v174, _v176}
return _v177
end
_block_58 = function() _v178 = _v108[2]
_v179 = _v106(_v178, _v107)
_v180 = {15, _v179}
return _v180
end
_block_59 = function() _v181 = _v108[2]
_v182 = _v106(_v181, _v107)
_v183 = {16, _v182}
return _v183
end
_block_60 = function() _v184 = _v108[3]
_v185 = _v108[2]
_v186 = _v106(_v184, _v107)
_v187 = {17, _v185, _v186}
return _v187
end
_block_61 = function() _v188 = _v108[3]
_v189 = _v108[2]
_v190 = _v106(_v188, _v107)
_v191 = {18, _v189, _v190}
return _v191
end
_block_62 = function() _v192 = _v108[2]
_v193 = _v106(_v192, _v107)
_v194 = {19, _v193}
return _v194
end
_block_63 = function() _v195 = _v108[4]
_v196 = _v108[3]
_v197 = _v108[2]
_v198 = _v106(_v195, _v107)
_v199 = {20, _v197, _v196, _v198}
return _v199
end
_block_64 = function() _v200 = _v108[3]
_v201 = _v108[2]
_v202 = _v106(_v200, _v107)
_v203 = {21, _v201, _v202}
return _v203
end
_block_65 = function() _v204 = _v108[2]
_v205 = _v106(_v204, _v107)
_v206 = {22, _v205}
return _v206
end
_block_66 = function() _v207 = _v108[3]
_v208 = _v108[2]
_v209 = _v106(_v207, _v107)
_v210 = {23, _v208, _v209}
return _v210
end
_block_67 = function() _v211 = _v108[4]
_v212 = _v108[3]
_v213 = _v108[2]
_v214 = _v106(_v211, _v107)
_v215 = {24, _v213, _v212, _v214}
return _v215
end
_block_68 = function() _v336 = type(_v219) == "number"
if _v336 then return _block_69()
 else return _block_70()
 end
end
_block_69 = function() if _v219 == 0 then return _block_71()
 end
end
_block_71 = function() _v221 = 0
return _v221
end
_block_70 = function() _v335 = direct_obj_tag(_v219)
if _v335 == 0 then return _block_72()
 else if _v335 == 1 then return _block_73()
 else if _v335 == 2 then return _block_74()
 else if _v335 == 3 then return _block_75()
 else if _v335 == 4 then return _block_76()
 else if _v335 == 5 then return _block_77()
 else if _v335 == 6 then return _block_78()
 else if _v335 == 7 then return _block_79()
 else if _v335 == 8 then return _block_80()
 else if _v335 == 9 then return _block_81()
 else if _v335 == 10 then return _block_82()
 else if _v335 == 11 then return _block_83()
 else if _v335 == 12 then return _block_84()
 else if _v335 == 13 then return _block_85()
 else if _v335 == 14 then return _block_86()
 else if _v335 == 15 then return _block_87()
 else if _v335 == 16 then return _block_88()
 else if _v335 == 17 then return _block_89()
 else if _v335 == 18 then return _block_90()
 else if _v335 == 19 then return _block_91()
 else if _v335 == 20 then return _block_92()
 else if _v335 == 21 then return _block_93()
 else if _v335 == 22 then return _block_94()
 else if _v335 == 23 then return _block_95()
 else if _v335 == 24 then return _block_96()
 end
 end
 end
 end
 end
 end
 end
 end
 end
 end
 end
 end
 end
 end
 end
 end
 end
 end
 end
 end
 end
 end
 end
 end
 end
end
_block_72 = function() _v222 = _v219[2]
_v223 = _v218(_v220, _v222)
_v224 = {0, _v223}
return _v224
end
_block_73 = function() _v225 = _v219[2]
_v226 = _v218(_v220, _v225)
_v227 = {1, _v226}
return _v227
end
_block_74 = function() _v228 = _v219[3]
_v229 = _v219[2]
_v230 = _v218(_v220, _v228)
_v231 = {2, _v229, _v230}
return _v231
end
_block_75 = function() _v232 = _v219[3]
_v233 = _v219[2]
_v234 = _v218(_v220, _v232)
_v235 = {3, _v233, _v234}
return _v235
end
_block_76 = function() _v236 = _v219[5]
_v237 = _v219[4]
_v238 = _v219[3]
_v239 = _v219[2]
_v240 = _v218(_v220, _v236)
_v241 = {4, _v239, _v238, _v237, _v240}
return _v241
end
_block_77 = function() _v242 = _v219[5]
_v243 = _v219[4]
_v244 = _v219[3]
_v245 = _v219[2]
_v246 = _v218(_v220, _v242)
_v247 = {5, _v245, _v244, _v243, _v246}
return _v247
end
_block_78 = function() _v248 = _v219[5]
_v249 = _v219[4]
_v250 = _v219[3]
_v251 = _v219[2]
_v252 = _v218(_v220, _v248)
_v253 = {6, _v251, _v250, _v249, _v252}
return _v253
end
_block_79 = function() _v254 = _v219[5]
_v255 = _v219[4]
_v256 = _v219[3]
_v257 = _v219[2]
_v258 = _v218(_v220, _v254)
_v259 = {7, _v257, _v256, _v255, _v258}
return _v259
end
_block_80 = function() _v260 = _v219[5]
_v261 = _v219[4]
_v262 = _v219[3]
_v263 = _v219[2]
_v264 = _v218(_v220, _v260)
_v265 = {8, _v263, _v262, _v261, _v264}
return _v265
end
_block_81 = function() _v266 = _v219[3]
_v267 = _v219[2]
_v268 = _v218(_v220, _v266)
_v269 = {9, _v267, _v268}
return _v269
end
_block_82 = function() _v270 = _v219[2]
_v271 = _v218(_v220, _v270)
_v272 = {10, _v271}
return _v272
end
_block_83 = function() _v273 = _v219[3]
_v274 = _v219[2]
_v275 = _v218(_v220, _v273)
_v276 = -1953941022
_v277 = {0, _v276, _v274}
_v278 = _v220[2]
_v279 = _v278(_v277, _v275)
return _v279
end
_block_84 = function() _v280 = _v219[3]
_v281 = _v219[2]
_v282 = _v218(_v220, _v280)
_v283 = 1496389100
_v284 = {0, _v283, _v281}
_v285 = _v220[2]
_v286 = _v285(_v284, _v282)
return _v286
end
_block_85 = function() _v287 = _v219[4]
_v288 = _v219[3]
_v289 = _v219[2]
_v290 = _v218(_v220, _v287)
_v291 = {13, _v289, _v288, _v290}
return _v291
end
_block_86 = function() _v292 = _v219[4]
_v293 = _v219[3]
_v294 = _v219[2]
_v295 = _v218(_v220, _v292)
_v296 = {14, _v294, _v293, _v295}
return _v296
end
_block_87 = function() _v297 = _v219[2]
_v298 = _v218(_v220, _v297)
_v299 = {15, _v298}
return _v299
end
_block_88 = function() _v300 = _v219[2]
_v301 = _v218(_v220, _v300)
_v302 = {16, _v301}
return _v302
end
_block_89 = function() _v303 = _v219[3]
_v304 = _v219[2]
_v305 = _v218(_v220, _v303)
_v306 = {17, _v304, _v305}
return _v306
end
_block_90 = function() _v307 = _v219[3]
_v308 = _v219[2]
_v309 = _v218(_v220, _v307)
_v310 = {18, _v308, _v309}
return _v310
end
_block_91 = function() _v311 = _v219[2]
_v312 = _v218(_v220, _v311)
_v313 = {19, _v312}
return _v313
end
_block_92 = function() _v314 = _v219[4]
_v315 = _v219[3]
_v316 = _v219[2]
_v317 = _v218(_v220, _v314)
_v318 = {20, _v316, _v315, _v317}
return _v318
end
_block_93 = function() _v319 = _v219[3]
_v320 = _v219[2]
_v321 = _v218(_v220, _v319)
_v322 = {21, _v320, _v321}
return _v322
end
_block_94 = function() _v323 = _v219[2]
_v324 = _v218(_v220, _v323)
_v325 = {22, _v324}
return _v325
end
_block_95 = function() _v326 = _v219[3]
_v327 = _v219[2]
_v328 = _v218(_v220, _v326)
_v329 = {23, _v327, _v328}
return _v329
end
_block_96 = function() _v330 = _v219[4]
_v331 = _v219[3]
_v332 = _v219[2]
_v333 = _v218(_v220, _v330)
_v334 = {24, _v332, _v331, _v333}
return _v334
end
_block_297 = function() _v339 = 398
_v342 = {0, Invalid_argument_341, _v340}
_v344 = caml_register_named_value(_v343, _v342)
_v345 = function(_v346) return _block_296(_v346)
end
_v349 = function(_v350) return _block_295(_v350)
end
_v352 = 0
_v353 = caml_fresh_oo_id(_v352)
_v355 = {248, _v354, _v353}
_v366 = function(_v368, _v367) return _block_292(_v368, _v367)
end
_v370 = function(_v372, _v371) return _block_289(_v372, _v371)
end
_v374 = function(_v375) return _block_286(_v375)
end
_v378 = function(_v379) return _block_285(_v379)
end
_v382 = 2
_v383 = -2
_v384 = int_lsr(_v383, _v382)
_v385 = 2
_v386 = int_add(_v384, _v385)
_v388 = caml_int64_float_of_bits(_v387)
_v390 = caml_int64_float_of_bits(_v389)
_v392 = caml_int64_float_of_bits(_v391)
_v394 = caml_int64_float_of_bits(_v393)
_v396 = caml_int64_float_of_bits(_v395)
_v398 = caml_int64_float_of_bits(_v397)
_v399 = function(_v401, _v400) return _block_284(_v401, _v400)
end
_v412 = function(_v413) return _block_280(_v413)
end
_v420 = function(_v421) return _block_277(_v421)
end
_v424 = function(_v425) return _block_272(_v425)
end
_v434 = function(_v435) return _block_267(_v435)
end
_v443 = function(_v444) return _block_266(_v444)
end
_v447 = function(_v448) return _block_259(_v448)
end
_v456 = function(_v457) return _block_258(_v457)
end
_v479 = function(_v480) return _block_248(_v480)
end
_v484 = function(_v485) return _block_241(_v485)
end
_v493 = function(_v496, _v495) return _block_98(_v496, _v495)
end
_v494 = function(_v515, _v514, _v513, _v512) return _block_105(_v515, _v514, _v513, _v512)
end
_v535 = 0
_v536 = caml_ml_open_descriptor_in(_v535)
_v537 = 2
_v538 = caml_ml_open_descriptor_out(_v537)
_v539 = 4
_v540 = caml_ml_open_descriptor_out(_v539)
_v541 = function(_v544, _v543, _v542) return _block_240(_v544, _v543, _v542)
end
_v548 = function(_v549) return _block_239(_v549)
end
_v553 = function(_v554) return _block_238(_v554)
end
_v558 = function(_v559) return _block_237(_v559)
end
_v582 = function(_v584, _v583) return _block_225(_v584, _v583)
end
_v588 = function(_v590, _v589) return _block_224(_v590, _v589)
end
_v594 = function(_v598, _v597, _v596, _v595) return _block_219(_v598, _v597, _v596, _v595)
end
_v612 = function(_v616, _v615, _v614, _v613) return _block_214(_v616, _v615, _v614, _v613)
end
_v630 = function(_v632, _v631) return _block_213(_v632, _v631)
end
_v635 = function(_v636) return _block_212(_v636)
end
_v639 = function(_v640) return _block_202(_v640)
end
_v652 = function(_v655, _v654, _v653) return _block_201(_v655, _v654, _v653)
end
_v659 = function(_v660) return _block_200(_v660)
end
_v664 = function(_v665) return _block_199(_v665)
end
_v669 = function(_v673, _v672, _v671, _v670) return _block_194(_v673, _v672, _v671, _v670)
end
_v687 = function(_v691, _v690, _v689, _v688) return _block_112(_v691, _v690, _v689, _v688)
end
_v699 = function(_v703, _v702, _v701, _v700) return _block_189(_v703, _v702, _v701, _v700)
end
_v717 = function(_v719, _v718) return _block_188(_v719, _v718)
end
_v724 = function(_v725) return _block_187(_v725)
end
_v775 = function(_v776) return _block_170(_v776)
end
_v781 = function(_v782) return _block_169(_v782)
end
_v784 = function(_v785) return _block_168(_v785)
end
_v787 = function(_v788) return _block_167(_v788)
end
_v790 = function(_v791) return _block_166(_v791)
end
_v794 = function(_v795) return _block_165(_v795)
end
_v798 = function(_v799) return _block_164(_v799)
end
_v804 = function(_v805) return _block_163(_v805)
end
_v809 = function(_v810) return _block_162(_v810)
end
_v812 = function(_v813) return _block_161(_v813)
end
_v815 = function(_v816) return _block_160(_v816)
end
_v818 = function(_v819) return _block_159(_v819)
end
_v822 = function(_v823) return _block_158(_v823)
end
_v826 = function(_v827) return _block_157(_v827)
end
_v832 = function(_v833) return _block_156(_v833)
end
_v837 = function(_v838) return _block_155(_v838)
end
_v841 = function(_v842) return _block_154(_v842)
end
_v846 = function(_v847) return _block_153(_v847)
end
_v851 = function(_v852) return _block_152(_v852)
end
_v856 = function(_v857) return _block_151(_v857)
end
_v861 = {0}
_v862 = function(_v863) return _block_150(_v863)
end
_v865 = function(_v867, _v866) return _block_149(_v867, _v866)
end
_v878 = {0, _v558}
_v879 = function(_v880) return _block_120(_v880)
end
_v901 = function(_v902) return _block_148(_v902)
end
_v904 = {0, _v901}
_v905 = function(_v906) return _block_147(_v906)
end
_v914 = function(_v915) return _block_146(_v915)
end
_v920 = caml_register_named_value(_v919, _v905)
_v921 = function(_v922) return _block_145(_v922)
end
_v924 = function(_v925) return _block_144(_v925)
end
_v927 = function(_v929, _v928) return _block_143(_v929, _v928)
end
_v931 = function(_v932) return _block_142(_v932)
end
_v934 = function(_v935) return _block_141(_v935)
end
_v937 = function(_v939, _v938) return _block_140(_v939, _v938)
end
_v941 = {0, _v937, _v934, _v931, _v927, _v924, _v921}
_v942 = function(_v944, _v943) return _block_139(_v944, _v943)
end
_v946 = function(_v947) return _block_138(_v947)
end
_v949 = function(_v950) return _block_137(_v950)
end
_v952 = function(_v953) return _block_136(_v953)
end
_v955 = function(_v957, _v956) return _block_135(_v957, _v956)
end
_v959 = function(_v960) return _block_134(_v960)
end
_v962 = function(_v963) return _block_133(_v963)
end
_v965 = function(_v966) return _block_132(_v966)
end
_v968 = function(_v969) return _block_131(_v969)
end
_v971 = function(_v973, _v972) return _block_130(_v973, _v972)
end
_v975 = function(_v976) return _block_129(_v976)
end
_v978 = function(_v979) return _block_128(_v979)
end
_v981 = function(_v983, _v982) return _block_127(_v983, _v982)
end
_v985 = function(_v987, _v986) return _block_126(_v987, _v986)
end
_v989 = function(_v991, _v990) return _block_125(_v991, _v990)
end
_v993 = function(_v995, _v994) return _block_124(_v995, _v994)
end
_v997 = function(_v998) return _block_123(_v998)
end
_v1000 = {0, _v349, _v345, _v355, Match_failure_356, Assert_failure_357, Invalid_argument_341, Failure_347, Not_found_358, Out_of_memory_359, Stack_overflow_360, Sys_error_361, End_of_file_362, Division_by_zero_363, Sys_blocked_io_364, Undefined_recursive_module_365, _v366, _v370, _v374, _v384, _v386, _v378, _v388, _v390, _v392, _v394, _v396, _v398, _v399, _v412, _v420, _v434, _v424, _v443, _v447, _v479, _v484, _v493, _v536, _v538, _v540, _v781, _v784, _v787, _v790, _v794, _v798, _v804, _v809, _v812, _v815, _v818, _v822, _v826, _v832, _v837, _v846, _v841, _v856, _v851, _v548, _v553, _v541, _v997, _v558, _v993, _v588, _v582, _v594, _v612, _v989, _v985, _v630, _v981, _v978, _v975, _v635, _v639, _v971, _v659, _v664, _v652, _v968, _v724, _v669, _v699, _v717, _v965, _v962, _v959, _v955, _v952, _v949, _v946, _v775, _v942, _v941, _v862, _v865, _v914, _v879, _v456, _v687, _v905, _v904}
_v1001 = 0
_v1003 = _v1000[43]
_v1004 = _v1003(_v1002)
_v1005 = {0}
_v1006 = 0
_v1007 = 0
_v1008 = _v1000[104]
_v1009 = _v1008(_v1007)
_v1010 = {0}
_v1011 = 0
return
end
_block_296 = function() _v348 = {0, Failure_347, _v346}
error(_v348)
end
_block_295 = function() _v351 = {0, Invalid_argument_341, _v350}
error(_v351)
end
_block_292 = function() _v369 = caml_lessequal(_v368, _v367)
if _v369 then return _block_293()
 else return _block_294()
 end
end
_block_293 = function() return _v368
end
_block_294 = function() return _v367
end
_block_289 = function() _v373 = caml_greaterequal(_v372, _v371)
if _v373 then return _block_290()
 else return _block_291()
 end
end
_block_290 = function() return _v372
end
_block_291 = function() return _v371
end
_block_286 = function() _v376 = 0 <= _v375
if _v376 then return _block_287()
 else return _block_288()
 end
end
_block_287 = function() return _v375
end
_block_288 = function() _v377 = int_neg(_v375)
return _v377
end
_block_285 = function() _v380 = -2
_v381 = int_xor(_v379, _v380)
return _v381
end
_block_284 = function() _v402 = caml_ml_string_length(_v401)
_v403 = caml_ml_string_length(_v400)
_v404 = int_add(_v402, _v403)
_v405 = caml_create_bytes(_v404)
_v406 = 0
_v407 = 0
_v408 = caml_blit_string(_v401, _v407, _v405, _v406, _v402)
_v409 = 0
_v410 = caml_blit_string(_v400, _v409, _v405, _v402, _v403)
_v411 = caml_string_of_bytes(_v405)
return _v411
end
_block_280 = function() _v414 = 0 <= _v413
if _v414 then return _block_281()
 else return _block_282(_v413, _v413)
 end
end
_block_281 = function() _v415 = 510 < _v413
if _v415 then return _block_282(_v413, _v413)
 else return _block_283()
 end
end
_block_282 = function(_v416, _v417) _v419 = _v349(_v418)
return _v419
end
_block_283 = function() return _v413
end
_block_277 = function() if _v421 then return _block_278()
 else return _block_279()
 end
end
_block_278 = function() return _v422
end
_block_279 = function() return _v423
end
_block_272 = function() _v427 = caml_string_notequal(_v425, _v426)
if _v427 then return _block_273()
 else return _block_275()
 end
end
_block_273 = function() _v429 = caml_string_notequal(_v425, _v428)
if _v429 then return _block_276()
 else return _block_274()
 end
end
_block_276 = function() _v431 = _v349(_v430)
return _v431
end
_block_274 = function() _v432 = 2
return _v432
end
_block_275 = function() _v433 = 0
return _v433
end
_block_267 = function() _v437 = caml_string_notequal(_v435, _v436)
if _v437 then return _block_268()
 else return _block_270()
 end
end
_block_268 = function() _v439 = caml_string_notequal(_v435, _v438)
if _v439 then return _block_271()
 else return _block_269()
 end
end
_block_271 = function() _v440 = 0
return _v440
end
_block_269 = function() return _v441
end
_block_270 = function() return _v442
end
_block_266 = function() _v446 = caml_format_int(_v445, _v444)
return _v446
end
_block_259 = function() return _block_260(_v448)
end
_block_260 = function(_v449) local ok, res = pcall(function() return _block_263()
end)
if ok then return res
 else return _block_261(res)
 end
end
_block_261 = function() _v454 = caml_int_of_string(_v448)
_v455 = {0, _v454}
end
_block_263 = function() _v451 = _v450[2]
_v452 = _v451 == Failure_347
if _v452 then return _block_264()
 else return _block_265()
 end
end
_block_264 = function() _v453 = 0
return _v453
end
_block_265 = function() error(_v450)
end
_block_258 = function() _v458 = caml_ml_string_length(_v457)
_v459 = function(_v460) return _block_249(_v460)
end
_v477 = 0
_v478 = _v459(_v477)
return _v478
end
_block_249 = function() _v461 = _v458 <= _v460
if _v461 then return _block_250()
 else return _block_251()
 end
end
_block_250 = function() _v463 = _v399(_v457, _v462)
return _v463
end
_block_251 = function() _v464 = caml_string_get(_v457, _v460)
_v465 = 96 <= _v464
if _v465 then return _block_252()
 else return _block_254()
 end
end
_block_252 = function() _v466 = 116 <= _v464
if _v466 then return _block_256(_v460, _v464, _v464)
 else return _block_253()
 end
end
_block_256 = function(_v467, _v468, _v469) return _v457
end
_block_253 = function() return _block_257(_v460, _v464, _v464)
end
_block_257 = function(_v470, _v471, _v472) _v473 = 2
_v474 = int_add(_v470, _v473)
_v475 = _v459(_v474)
return _v475
end
_block_254 = function() _v476 = 90 == _v464
if _v476 then return _block_255()
 else return _block_256(_v460, _v464, _v464)
 end
end
_block_255 = function() return _block_257(_v460, _v464, _v464)
end
_block_248 = function() _v482 = caml_format_float(_v481, _v480)
_v483 = _v456(_v482)
return _v483
end
_block_241 = function() return _block_242(_v485)
end
_block_242 = function(_v486) local ok, res = pcall(function() return _block_245()
end)
if ok then return res
 else return _block_243(res)
 end
end
_block_243 = function() _v491 = caml_float_of_string(_v485)
_v492 = {0, _v491}
end
_block_245 = function() _v488 = _v487[2]
_v489 = _v488 == Failure_347
if _v489 then return _block_246()
 else return _block_247()
 end
end
_block_246 = function() _v490 = 0
return _v490
end
_block_247 = function() error(_v487)
end
_block_98 = function() if _v496 then return _block_99()
 else return _block_104()
 end
end
_block_99 = function() _v497 = _v496[3]
_v498 = _v496[2]
if _v497 then return _block_100()
 else return _block_103()
 end
end
_block_100 = function() _v499 = _v497[3]
_v500 = _v497[2]
if _v499 then return _block_101()
 else return _block_102()
 end
end
_block_101 = function() _v501 = _v499[3]
_v502 = _v499[2]
_v503 = 48058
_v504 = {0, _v502, _v503}
_v505 = 2
_v506 = _v494(_v504, _v505, _v501, _v495)
_v507 = {0, _v500, _v504}
_v508 = {0, _v498, _v507}
return _v508
end
_block_102 = function() _v509 = {0, _v500, _v495}
_v510 = {0, _v498, _v509}
return _v510
end
_block_103 = function() _v511 = {0, _v498, _v495}
return _v511
end
_block_104 = function() return _v495
end
_block_105 = function() if _v513 then return _block_106()
 else return _block_111()
 end
end
_block_106 = function() _v516 = _v513[3]
_v517 = _v513[2]
if _v516 then return _block_107()
 else return _block_110()
 end
end
_block_107 = function() _v518 = _v516[3]
_v519 = _v516[2]
if _v518 then return _block_108()
 else return _block_109()
 end
end
_block_108 = function() _v520 = _v518[3]
_v521 = _v518[2]
_v522 = 48058
_v523 = {0, _v521, _v522}
_v524 = {0, _v519, _v523}
_v525 = {0, _v517, _v524}
_v515[_v514 + 1] = _v525
_v526 = 0
_v527 = 2
_v528 = _v494(_v523, _v527, _v520, _v512)
return _v528
end
_block_109 = function() _v529 = {0, _v519, _v512}
_v530 = {0, _v517, _v529}
_v515[_v514 + 1] = _v530
_v531 = 0
return _v531
end
_block_110 = function() _v532 = {0, _v517, _v512}
_v515[_v514 + 1] = _v532
_v533 = 0
return _v533
end
_block_111 = function() _v515[_v514 + 1] = _v512
_v534 = 0
return _v534
end
_block_240 = function() _v545 = caml_sys_open(_v542, _v544, _v543)
_v546 = caml_ml_open_descriptor_out(_v545)
_v547 = caml_ml_set_channel_name(_v546, _v542)
return _v546
end
_block_239 = function() _v550 = 876
_v552 = _v541(_v551, _v550, _v549)
return _v552
end
_block_238 = function() _v555 = 876
_v557 = _v541(_v556, _v555, _v554)
return _v557
end
_block_237 = function() _v560 = function(_v561) return _block_226(_v561)
end
_v579 = 0
_v580 = caml_ml_out_channels_list(_v579)
_v581 = _v560(_v580)
return _v581
end
_block_226 = function() if _v561 then return _block_227()
 else return _block_236()
 end
end
_block_227 = function() _v562 = _v561[3]
_v563 = _v561[2]
return _block_228(_v561, _v562, _v563, _v563)
end
_block_228 = function(_v564, _v565, _v566, _v567) local ok, res = pcall(function() return _block_231()
end)
if ok then return res
 else return _block_229(res)
 end
end
_block_229 = function() _v577 = caml_ml_flush(_v563)
end
_block_231 = function() _v569 = _v568[2]
_v570 = _v569 == Sys_error_361
if _v570 then return _block_232()
 else return _block_233()
 end
end
_block_232 = function() _v571 = 0
return _block_234()
end
_block_234 = function() return _block_235(_v564, _v565, _v566, _v571)
end
_block_235 = function(_v572, _v573, _v574, _v575) _v576 = _v560(_v573)
return _v576
end
_block_233 = function() error(_v568)
end
_block_236 = function() _v578 = 0
return _v578
end
_block_225 = function() _v585 = caml_ml_bytes_length(_v583)
_v586 = 0
_v587 = caml_ml_output_bytes(_v584, _v583, _v586, _v585)
return _v587
end
_block_224 = function() _v591 = caml_ml_string_length(_v589)
_v592 = 0
_v593 = caml_ml_output(_v590, _v589, _v592, _v591)
return _v593
end
_block_219 = function() _v599 = 0 <= _v596
if _v599 then return _block_220()
 else return _block_222(_v595, _v596, _v597, _v598, _v596)
 end
end
_block_220 = function() _v600 = 0 <= _v595
if _v600 then return _block_221()
 else return _block_222(_v595, _v596, _v597, _v598, _v595)
 end
end
_block_221 = function() _v601 = caml_ml_bytes_length(_v597)
_v602 = int_sub(_v601, _v595)
_v603 = _v602 < _v596
if _v603 then return _block_222(_v595, _v596, _v597, _v598, _v603)
 else return _block_223()
 end
end
_block_222 = function(_v604, _v605, _v606, _v607, _v608) _v610 = _v349(_v609)
return _v610
end
_block_223 = function() _v611 = caml_ml_output_bytes(_v598, _v597, _v596, _v595)
return _v611
end
_block_214 = function() _v617 = 0 <= _v614
if _v617 then return _block_215()
 else return _block_217(_v613, _v614, _v615, _v616, _v614)
 end
end
_block_215 = function() _v618 = 0 <= _v613
if _v618 then return _block_216()
 else return _block_217(_v613, _v614, _v615, _v616, _v613)
 end
end
_block_216 = function() _v619 = caml_ml_string_length(_v615)
_v620 = int_sub(_v619, _v613)
_v621 = _v620 < _v614
if _v621 then return _block_217(_v613, _v614, _v615, _v616, _v621)
 else return _block_218()
 end
end
_block_217 = function(_v622, _v623, _v624, _v625, _v626) _v628 = _v349(_v627)
return _v628
end
_block_218 = function() _v629 = caml_ml_output(_v616, _v615, _v614, _v613)
return _v629
end
_block_213 = function() _v633 = 0
_v634 = caml_output_value(_v632, _v631, _v633)
return _v634
end
_block_212 = function() _v637 = caml_ml_flush(_v636)
_v638 = caml_ml_close_channel(_v636)
return _v638
end
_block_202 = function() return _block_203(_v640)
end
_block_203 = function(_v641) local ok, res = pcall(function() return _block_206()
end)
if ok then return res
 else return _block_204(res)
 end
end
_block_204 = function() _v651 = caml_ml_flush(_v640)
end
_block_206 = function() _v643 = 0
return _block_207(_v641, _v643)
end
_block_207 = function(_v644, _v645) return _block_208(_v644, _v645)
end
_block_208 = function(_v646, _v647) local ok, res = pcall(function() return _block_211()
end)
if ok then return res
 else return _block_209(res)
 end
end
_block_209 = function() _v650 = caml_ml_close_channel(_v644)
end
_block_211 = function() _v649 = 0
return _v649
end
_block_201 = function() _v656 = caml_sys_open(_v653, _v655, _v654)
_v657 = caml_ml_open_descriptor_in(_v656)
_v658 = caml_ml_set_channel_name(_v657, _v653)
return _v657
end
_block_200 = function() _v661 = 0
_v663 = _v652(_v662, _v661, _v660)
return _v663
end
_block_199 = function() _v666 = 0
_v668 = _v652(_v667, _v666, _v665)
return _v668
end
_block_194 = function() _v674 = 0 <= _v671
if _v674 then return _block_195()
 else return _block_197(_v670, _v671, _v672, _v673, _v671)
 end
end
_block_195 = function() _v675 = 0 <= _v670
if _v675 then return _block_196()
 else return _block_197(_v670, _v671, _v672, _v673, _v670)
 end
end
_block_196 = function() _v676 = caml_ml_bytes_length(_v672)
_v677 = int_sub(_v676, _v670)
_v678 = _v677 < _v671
if _v678 then return _block_197(_v670, _v671, _v672, _v673, _v678)
 else return _block_198()
 end
end
_block_197 = function(_v679, _v680, _v681, _v682, _v683) _v685 = _v349(_v684)
return _v685
end
_block_198 = function() _v686 = caml_ml_input(_v673, _v672, _v671, _v670)
return _v686
end
_block_112 = function() _v692 = 0 < _v688
if _v692 then return _block_114()
 else return _block_113()
 end
end
_block_114 = function() _v693 = caml_ml_input(_v691, _v690, _v689, _v688)
_v694 = 0 == _v693
if _v694 then return _block_115()
 else return _block_116()
 end
end
_block_115 = function() error(End_of_file_362)
end
_block_116 = function() _v695 = int_sub(_v688, _v693)
_v696 = int_add(_v689, _v693)
_v697 = _v687(_v691, _v690, _v696, _v695)
return _v697
end
_block_113 = function() _v698 = 0
return _v698
end
_block_189 = function() _v704 = 0 <= _v701
if _v704 then return _block_190()
 else return _block_192(_v700, _v701, _v702, _v703, _v701)
 end
end
_block_190 = function() _v705 = 0 <= _v700
if _v705 then return _block_191()
 else return _block_192(_v700, _v701, _v702, _v703, _v700)
 end
end
_block_191 = function() _v706 = caml_ml_bytes_length(_v702)
_v707 = int_sub(_v706, _v700)
_v708 = _v707 < _v701
if _v708 then return _block_192(_v700, _v701, _v702, _v703, _v708)
 else return _block_193()
 end
end
_block_192 = function(_v709, _v710, _v711, _v712, _v713) _v715 = _v349(_v714)
return _v715
end
_block_193 = function() _v716 = _v687(_v703, _v702, _v701, _v700)
return _v716
end
_block_188 = function() _v720 = caml_create_bytes(_v718)
_v721 = 0
_v722 = _v699(_v719, _v720, _v721, _v718)
_v723 = caml_string_of_bytes(_v720)
return _v723
end
_block_187 = function() _v726 = function(_v729, _v728, _v727) return _block_175(_v729, _v728, _v727)
end
_v738 = function(_v740, _v739) return _block_178(_v740, _v739)
end
_v771 = 0
_v772 = 0
_v773 = _v738(_v772, _v771)
_v774 = caml_string_of_bytes(_v773)
return _v774
end
_block_175 = function() if _v727 then return _block_176()
 else return _block_177()
 end
end
_block_176 = function() _v730 = _v727[3]
_v731 = _v727[2]
_v732 = caml_ml_bytes_length(_v731)
_v733 = int_sub(_v728, _v732)
_v734 = 0
_v735 = caml_blit_bytes(_v731, _v734, _v729, _v733, _v732)
_v736 = int_sub(_v728, _v732)
_v737 = _v726(_v729, _v736, _v730)
return _v737
end
_block_177 = function() return _v729
end
_block_178 = function() _v741 = caml_ml_input_scan_line(_v725)
_v742 = 0 == _v741
if _v742 then return _block_179()
 else return _block_182()
 end
end
_block_179 = function() if _v740 then return _block_180()
 else return _block_181()
 end
end
_block_180 = function() _v743 = caml_create_bytes(_v739)
_v744 = _v726(_v743, _v739, _v740)
return _v744
end
_block_181 = function() error(End_of_file_362)
end
_block_182 = function() _v745 = 0 < _v741
if _v745 then return _block_183()
 else return _block_186()
 end
end
_block_183 = function() _v746 = -2
_v747 = int_add(_v741, _v746)
_v748 = caml_create_bytes(_v747)
_v749 = -2
_v750 = int_add(_v741, _v749)
_v751 = 0
_v752 = caml_ml_input(_v725, _v748, _v751, _v750)
_v753 = 0
_v754 = caml_ml_input_char(_v725)
_v755 = 0
if _v740 then return _block_184()
 else return _block_185()
 end
end
_block_184 = function() _v756 = int_add(_v739, _v741)
_v757 = -2
_v758 = int_add(_v756, _v757)
_v759 = {0, _v748, _v740}
_v760 = caml_create_bytes(_v758)
_v761 = _v726(_v760, _v758, _v759)
return _v761
end
_block_185 = function() return _v748
end
_block_186 = function() _v762 = int_neg(_v741)
_v763 = caml_create_bytes(_v762)
_v764 = int_neg(_v741)
_v765 = 0
_v766 = caml_ml_input(_v725, _v763, _v765, _v764)
_v767 = 0
_v768 = int_sub(_v739, _v741)
_v769 = {0, _v763, _v740}
_v770 = _v738(_v769, _v768)
return _v770
end
_block_170 = function() return _block_171(_v776)
end
_block_171 = function(_v777) local ok, res = pcall(function() return _block_174()
end)
if ok then return res
 else return _block_172(res)
 end
end
_block_172 = function() _v780 = caml_ml_close_channel(_v776)
end
_block_174 = function() _v779 = 0
return _v779
end
_block_169 = function() _v783 = caml_ml_output_char(_v538, _v782)
return _v783
end
_block_168 = function() _v786 = _v588(_v538, _v785)
return _v786
end
_block_167 = function() _v789 = _v582(_v538, _v788)
return _v789
end
_block_166 = function() _v792 = _v443(_v791)
_v793 = _v588(_v538, _v792)
return _v793
end
_block_165 = function() _v796 = _v479(_v795)
_v797 = _v588(_v538, _v796)
return _v797
end
_block_164 = function() _v800 = _v588(_v538, _v799)
_v801 = 20
_v802 = caml_ml_output_char(_v538, _v801)
_v803 = caml_ml_flush(_v538)
return _v803
end
_block_163 = function() _v806 = 20
_v807 = caml_ml_output_char(_v538, _v806)
_v808 = caml_ml_flush(_v538)
return _v808
end
_block_162 = function() _v811 = caml_ml_output_char(_v540, _v810)
return _v811
end
_block_161 = function() _v814 = _v588(_v540, _v813)
return _v814
end
_block_160 = function() _v817 = _v582(_v540, _v816)
return _v817
end
_block_159 = function() _v820 = _v443(_v819)
_v821 = _v588(_v540, _v820)
return _v821
end
_block_158 = function() _v824 = _v479(_v823)
_v825 = _v588(_v540, _v824)
return _v825
end
_block_157 = function() _v828 = _v588(_v540, _v827)
_v829 = 20
_v830 = caml_ml_output_char(_v540, _v829)
_v831 = caml_ml_flush(_v540)
return _v831
end
_block_156 = function() _v834 = 20
_v835 = caml_ml_output_char(_v540, _v834)
_v836 = caml_ml_flush(_v540)
return _v836
end
_block_155 = function() _v839 = caml_ml_flush(_v538)
_v840 = _v724(_v536)
return _v840
end
_block_154 = function() _v843 = 0
_v844 = _v837(_v843)
_v845 = caml_int_of_string(_v844)
return _v845
end
_block_153 = function() _v848 = 0
_v849 = _v837(_v848)
_v850 = _v447(_v849)
return _v850
end
_block_152 = function() _v853 = 0
_v854 = _v837(_v853)
_v855 = caml_float_of_string(_v854)
return _v855
end
_block_151 = function() _v858 = 0
_v859 = _v837(_v858)
_v860 = _v484(_v859)
return _v860
end
_block_150 = function() _v864 = _v863[3]
return _v864
end
_block_149 = function() _v868 = _v866[3]
_v869 = _v866[2]
_v870 = _v867[3]
_v871 = _v867[2]
_v873 = _v399(_v872, _v868)
_v874 = _v399(_v870, _v873)
_v875 = _v337[4]
_v876 = _v875(_v871, _v869)
_v877 = {0, _v876, _v874}
return _v877
end
_block_120 = function() _v881 = 2
_v882 = {0, _v881}
_v883 = 0
_v884 = caml_atomic_load_field(_v878, _v883)
_v885 = function(_v886) return _block_117(_v886)
end
_v897 = 0
_v898 = caml_atomic_cas_field(_v878, _v897, _v884, _v885)
_v899 = not _v898
if _v899 then return _block_121()
 else return _block_122()
 end
end
_block_117 = function() _v887 = 0
_v888 = 2
_v889 = 0
_v890 = caml_atomic_cas_field(_v882, _v889, _v888, _v887)
if _v890 then return _block_118()
 else return _block_119(_v886, _v890)
 end
end
_block_118 = function() _v891 = 0
_v892 = _v880(_v891)
return _block_119(_v886, _v892)
end
_block_119 = function(_v893, _v894) _v895 = 0
_v896 = _v884(_v895)
return _v896
end
_block_121 = function() _v900 = _v879(_v880)
return _v900
end
_block_122 = function() return _v899
end
_block_148 = function() _v903 = 0
return _v903
end
_block_147 = function() _v907 = 0
_v908 = _v904[2]
_v909 = _v908(_v907)
_v910 = 0
_v911 = 0
_v912 = caml_atomic_load_field(_v878, _v911)
_v913 = _v912(_v910)
return _v913
end
_block_146 = function() _v916 = 0
_v917 = _v905(_v916)
_v918 = caml_sys_exit(_v915)
return _v918
end
_block_145 = function() _v923 = caml_ml_channel_size_64(_v922)
return _v923
end
_block_144 = function() _v926 = caml_ml_pos_in_64(_v925)
return _v926
end
_block_143 = function() _v930 = caml_ml_seek_in_64(_v929, _v928)
return _v930
end
_block_142 = function() _v933 = caml_ml_channel_size_64(_v932)
return _v933
end
_block_141 = function() _v936 = caml_ml_pos_out_64(_v935)
return _v936
end
_block_140 = function() _v940 = caml_ml_seek_out_64(_v939, _v938)
return _v940
end
_block_139 = function() _v945 = caml_ml_set_binary_mode(_v944, _v943)
return _v945
end
_block_138 = function() _v948 = caml_ml_close_channel(_v947)
return _v948
end
_block_137 = function() _v951 = caml_ml_channel_size(_v950)
return _v951
end
_block_136 = function() _v954 = caml_ml_pos_in(_v953)
return _v954
end
_block_135 = function() _v958 = caml_ml_seek_in(_v957, _v956)
return _v958
end
_block_134 = function() _v961 = caml_input_value(_v960)
return _v961
end
_block_133 = function() _v964 = caml_ml_input_int(_v963)
return _v964
end
_block_132 = function() _v967 = caml_ml_input_char(_v966)
return _v967
end
_block_131 = function() _v970 = caml_ml_input_char(_v969)
return _v970
end
_block_130 = function() _v974 = caml_ml_set_binary_mode(_v973, _v972)
return _v974
end
_block_129 = function() _v977 = caml_ml_channel_size(_v976)
return _v977
end
_block_128 = function() _v980 = caml_ml_pos_out(_v979)
return _v980
end
_block_127 = function() _v984 = caml_ml_seek_out(_v983, _v982)
return _v984
end
_block_126 = function() _v988 = caml_ml_output_int(_v987, _v986)
return _v988
end
_block_125 = function() _v992 = caml_ml_output_char(_v991, _v990)
return _v992
end
_block_124 = function() _v996 = caml_ml_output_char(_v995, _v994)
return _v996
end
_block_123 = function() _v999 = caml_ml_flush(_v998)
return _v999
end
_block_0()

-- Entry point
io.stderr:write("=== START ===\n")
local ok, err = pcall(_block_0)
if not ok then io.stderr:write("ERROR: " .. tostring(err) .. "\n") end
io.stderr:write("=== DONE ===\n")
