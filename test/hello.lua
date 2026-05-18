-- source: test/hello.byte
-- lua_of_ocaml runtime: standard library (globals, call support)
-- Provides: caml_register_global caml_register_named_value caml_get_global
--           caml_fresh_oo_id caml_call_gen caml_set_global caml_bind_frame

local math_floor = math.floor

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

-- lua_of_ocaml runtime: integer arithmetic and bitwise operations
-- Provides: caml_mul caml_div caml_mod
--           int_and int_or int_xor int_lsl int_lsr int_asr int_add int_sub int_neg
--           caml_and caml_or caml_xor caml_lsl caml_lsr caml_asr
--           caml_eq caml_neq caml_lt caml_le caml_gt caml_ge
--           caml_lessequal caml_greaterequal caml_lessthan caml_greaterthan
--           caml_not caml_is_int

local math_floor = math.floor

function caml_mul(a, b) return math_floor(a * b / 2) end
function caml_div(a, b) return math_floor(math_floor(a / 2) / math_floor(b / 2)) * 2 end
function caml_mod(a, b)
  local a2 = math_floor(a / 2)
  local b2 = math_floor(b / 2)
  local m = a2 % b2
  if m < 0 then m = m + b2 end return m * 2
end

-- Pure-Lua bitwise for Lua 5.1
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

function int_and(a, b) return uint_and(math_floor(a/2), math_floor(b/2)) * 2 end
function int_or(a, b)  return uint_or(math_floor(a/2), math_floor(b/2)) * 2 end
function int_xor(a, b) return uint_xor(math_floor(a/2), math_floor(b/2)) * 2 end
function int_lsl(a, b) return uint_shl(math_floor(a/2), math_floor(b/2)) * 2 end
function int_lsr(a, b) return uint_shr(math_floor(a/2), math_floor(b/2)) * 2 end
function int_asr(a, b)
  local a2 = math_floor(a / 2); local b2 = math_floor(b / 2)
  if a2 >= 2^31 then a2 = a2 - 2^32 end
  return math_floor(a2 / (2 ^ b2)) * 2
end
function int_add(a, b) return a + b end
function int_sub(a, b) return a - b end
function int_neg(a) return -a end

caml_and = int_and; caml_or = int_or; caml_xor = int_xor
caml_lsl = int_lsl; caml_lsr = int_lsr; caml_asr = int_asr

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

function caml_not(x) return (x == 0) and 2 or 0 end
function caml_is_int(x) return type(x) == "number" end

-- lua_of_ocaml runtime: block and object operations
-- Provides: caml_obj_tag caml_obj_block caml_obj_dup caml_obj_set_raw_field

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

-- lua_of_ocaml runtime: exceptions
-- Provides: caml_failwith caml_invalid_argument caml_raise

function caml_failwith(msg) error(msg) end
function caml_invalid_argument(msg) error("Invalid_argument: " .. msg) end
function caml_raise(exn)
  return 0
end

-- lua_of_ocaml runtime: string and bytes operations
-- Provides: caml_string_length caml_ml_string_length caml_string_get
--           caml_create_string caml_create_bytes caml_ml_bytes_length
--           caml_blit_string caml_blit_bytes caml_fill_string caml_fill_bytes
--           caml_string_notequal caml_string_equal caml_string_compare
--           caml_bytes_compare caml_string_concat caml_string_of_bytes caml_bytes_of_string

local math_floor = math.floor

function caml_string_length(s)
  if s == nil then return 0 end return #s
end

function caml_ml_string_length(s)
  if s == nil then return 0 end return #s
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
  if b == nil then return 0 end return #b
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

-- lua_of_ocaml runtime: array and vector operations
-- Provides: caml_vect_length caml_array_get caml_array_set
--           caml_array_unsafe_get caml_array_unsafe_set

local math_floor = math.floor

function caml_vect_length(v) return (#v - 1) * 2 end
function caml_array_get(v, i) return v[math_floor(i / 2) + 2] or 0 end
function caml_array_set(v, i, x) v[math_floor(i / 2) + 2] = x; return 0 end
function caml_array_unsafe_get(v, i) return caml_array_get(v, i) end
function caml_array_unsafe_set(v, i, x) return caml_array_set(v, i, x) end

-- lua_of_ocaml runtime: channel I/O
-- Provides: caml_ml_open_descriptor_in caml_ml_open_descriptor_out
--           caml_ml_output caml_ml_output_bytes caml_ml_output_char caml_ml_output_int
--           caml_ml_input caml_ml_input_char caml_ml_input_int caml_ml_input_scan_line
--           caml_ml_flush caml_ml_out_channels_list
--           caml_ml_channel_size caml_ml_channel_size_64 caml_ml_pos_in caml_ml_pos_in_64
--           caml_ml_pos_out caml_ml_pos_out_64 caml_ml_seek_in caml_ml_seek_in_64
--           caml_ml_seek_out caml_ml_seek_out_64 caml_ml_set_binary_mode
--           caml_ml_set_channel_name caml_ml_close_channel

local math_floor = math.floor

caml_ml_out_channels_list = function() return { 0, 0, 0 } end

function caml_ml_open_descriptor_in(fd) return fd end
function caml_ml_open_descriptor_out(fd) return fd end

function caml_ml_output(chan, s, ofs, len)
  if s == nil then return 0 end
  local o = math_floor(ofs / 2) + 1
  local l = math_floor(len / 2)
  io.write(string.sub(s, o, o + l - 1))
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
  return string.byte(c) * 2
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
  if n == nil then return 0 end return n * 2
end

function caml_ml_input_scan_line(chan)
  local line = io.read("*l")
  if line == nil then return 0 end return line
end

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

_main = function() -- src: <unknown>
Out_of_memory_359 = nil
Sys_error_361 = nil
Failure_347 = nil
Invalid_argument_341 = nil
End_of_file_362 = nil
Division_by_zero_363 = nil
Not_found_358 = nil
Match_failure_356 = nil
Stack_overflow_360 = nil
Sys_blocked_io_364 = nil
Assert_failure_357 = nil
Undefined_recursive_module_365 = nil
_v872 = nil
_v714 = nil
_v684 = nil
_v667 = nil
_v662 = nil
_v627 = nil
_v609 = nil
_v556 = nil
_v551 = nil
_v481 = nil
_v462 = nil
_v445 = nil
_v436 = nil
_v438 = nil
_v441 = nil
_v442 = nil
_v426 = nil
_v428 = nil
_v430 = nil
_v422 = nil
_v423 = nil
_v418 = nil
_v340 = nil
_v343 = nil
_v354 = nil
_v387 = nil
_v389 = nil
_v391 = nil
_v393 = nil
_v395 = nil
_v397 = nil
_v919 = nil
_v1004 = nil
_v1009 = nil
_v1015 = nil
_v1028 = nil
_v1042 = nil
_v1041 = nil
_v1040 = nil
_v1039 = nil
_v1038 = nil
_v1037 = nil
_v1036 = nil
_v1035 = nil
_v1034 = nil
_v1033 = nil
_v1032 = nil
_v1031 = nil
_v52 = nil
_v51 = nil
_v3 = nil
rest_4 = nil
_v5 = nil
_v6 = nil
rest_7 = nil
_v8 = nil
_v9 = nil
rest_10 = nil
_v11 = nil
_v12 = nil
rest_13 = nil
_v14 = nil
_v15 = nil
rest_16 = nil
_v17 = nil
_v18 = nil
rest_19 = nil
_v20 = nil
_v21 = nil
rest_22 = nil
_v23 = nil
_v24 = nil
rest_25 = nil
_v26 = nil
_v27 = nil
rest_28 = nil
ty_29 = nil
_v30 = nil
_v31 = nil
rest_32 = nil
ty1_33 = nil
_v34 = nil
_v35 = nil
rest_36 = nil
_v37 = nil
_v38 = nil
rest_39 = nil
_v40 = nil
_v41 = nil
rest_42 = nil
_v43 = nil
_v44 = nil
rest_45 = nil
_v46 = nil
_v47 = nil
rest_48 = nil
_v49 = nil
_v50 = nil
_v105 = nil
_v104 = nil
rest_56 = nil
_v57 = nil
_v58 = nil
rest_59 = nil
_v60 = nil
_v61 = nil
rest_62 = nil
_v63 = nil
_v64 = nil
rest_65 = nil
_v66 = nil
_v67 = nil
rest_68 = nil
_v69 = nil
_v70 = nil
rest_71 = nil
_v72 = nil
_v73 = nil
rest_74 = nil
_v75 = nil
_v76 = nil
rest_77 = nil
_v78 = nil
_v79 = nil
rest_80 = nil
ty_81 = nil
_v82 = nil
_v83 = nil
rest_84 = nil
ty2_85 = nil
ty1_86 = nil
_v87 = nil
_v88 = nil
rest_89 = nil
_v90 = nil
_v91 = nil
rest_92 = nil
_v93 = nil
_v94 = nil
rest_95 = nil
_v96 = nil
_v97 = nil
rest_98 = nil
_v99 = nil
_v100 = nil
rest_101 = nil
_v102 = nil
_v103 = nil
_v217 = nil
_v216 = nil
rest_109 = nil
_v110 = nil
_v111 = nil
rest_112 = nil
_v113 = nil
_v114 = nil
rest_115 = nil
pad_116 = nil
_v117 = nil
_v118 = nil
rest_119 = nil
pad_120 = nil
_v121 = nil
_v122 = nil
rest_123 = nil
prec_124 = nil
pad_125 = nil
iconv_126 = nil
_v127 = nil
_v128 = nil
rest_129 = nil
prec_130 = nil
pad_131 = nil
iconv_132 = nil
_v133 = nil
_v134 = nil
rest_135 = nil
prec_136 = nil
pad_137 = nil
iconv_138 = nil
_v139 = nil
_v140 = nil
rest_141 = nil
prec_142 = nil
pad_143 = nil
iconv_144 = nil
_v145 = nil
_v146 = nil
rest_147 = nil
prec_148 = nil
pad_149 = nil
fconv_150 = nil
_v151 = nil
_v152 = nil
rest_153 = nil
pad_154 = nil
_v155 = nil
_v156 = nil
rest_157 = nil
_v158 = nil
_v159 = nil
rest_160 = nil
str_161 = nil
_v162 = nil
_v163 = nil
rest_164 = nil
chr_165 = nil
_v166 = nil
_v167 = nil
rest_168 = nil
fmtty_169 = nil
pad_170 = nil
_v171 = nil
_v172 = nil
rest_173 = nil
fmtty_174 = nil
pad_175 = nil
_v176 = nil
_v177 = nil
rest_178 = nil
_v179 = nil
_v180 = nil
rest_181 = nil
_v182 = nil
_v183 = nil
rest_184 = nil
fmting_lit_185 = nil
_v186 = nil
_v187 = nil
rest_188 = nil
fmting_gen_189 = nil
_v190 = nil
_v191 = nil
rest_192 = nil
_v193 = nil
_v194 = nil
rest_195 = nil
char_set_196 = nil
width_opt_197 = nil
_v198 = nil
_v199 = nil
rest_200 = nil
counter_201 = nil
_v202 = nil
_v203 = nil
rest_204 = nil
_v205 = nil
_v206 = nil
rest_207 = nil
ign_208 = nil
_v209 = nil
_v210 = nil
rest_211 = nil
f_212 = nil
arity_213 = nil
_v214 = nil
_v215 = nil
_v336 = nil
_v335 = nil
_v221 = nil
rest_222 = nil
_v223 = nil
_v224 = nil
rest_225 = nil
_v226 = nil
_v227 = nil
rest_228 = nil
pad_229 = nil
_v230 = nil
_v231 = nil
rest_232 = nil
pad_233 = nil
_v234 = nil
_v235 = nil
rest_236 = nil
prec_237 = nil
pad_238 = nil
iconv_239 = nil
_v240 = nil
_v241 = nil
rest_242 = nil
prec_243 = nil
pad_244 = nil
iconv_245 = nil
_v246 = nil
_v247 = nil
rest_248 = nil
prec_249 = nil
pad_250 = nil
iconv_251 = nil
_v252 = nil
_v253 = nil
rest_254 = nil
prec_255 = nil
pad_256 = nil
iconv_257 = nil
_v258 = nil
_v259 = nil
rest_260 = nil
prec_261 = nil
pad_262 = nil
fconv_263 = nil
_v264 = nil
_v265 = nil
rest_266 = nil
pad_267 = nil
_v268 = nil
_v269 = nil
rest_270 = nil
_v271 = nil
_v272 = nil
rest_273 = nil
str_274 = nil
_v275 = nil
_v276 = nil
_v277 = nil
_v278 = nil
_v279 = nil
rest_280 = nil
chr_281 = nil
_v282 = nil
_v283 = nil
_v284 = nil
_v285 = nil
_v286 = nil
rest_287 = nil
fmtty_288 = nil
pad_289 = nil
_v290 = nil
_v291 = nil
rest_292 = nil
fmtty_293 = nil
pad_294 = nil
_v295 = nil
_v296 = nil
rest_297 = nil
_v298 = nil
_v299 = nil
rest_300 = nil
_v301 = nil
_v302 = nil
rest_303 = nil
fmting_lit_304 = nil
_v305 = nil
_v306 = nil
rest_307 = nil
fmting_gen_308 = nil
_v309 = nil
_v310 = nil
rest_311 = nil
_v312 = nil
_v313 = nil
rest_314 = nil
char_set_315 = nil
width_opt_316 = nil
_v317 = nil
_v318 = nil
rest_319 = nil
counter_320 = nil
_v321 = nil
_v322 = nil
rest_323 = nil
_v324 = nil
_v325 = nil
rest_326 = nil
ign_327 = nil
_v328 = nil
_v329 = nil
rest_330 = nil
fc_331 = nil
arity_332 = nil
_v333 = nil
_v334 = nil
erase_rel_1 = nil
concat_fmtty_53 = nil
concat_fmt_106 = nil
string_concat_map_218 = nil
_v337 = nil
_v338 = nil
match_497 = nil
h1_498 = nil
match_499 = nil
h2_500 = nil
tl_501 = nil
h3_502 = nil
_v503 = nil
block_504 = nil
_v505 = nil
_v506 = nil
_v507 = nil
_v508 = nil
_v509 = nil
_v510 = nil
_v511 = nil
match_516 = nil
h1_517 = nil
match_518 = nil
h2_519 = nil
tl_520 = nil
h3_521 = nil
_v522 = nil
_v523 = nil
_v524 = nil
_v525 = nil
_v526 = nil
_v527 = nil
_v528 = nil
_v529 = nil
_v530 = nil
_v531 = nil
_v532 = nil
_v533 = nil
_v534 = nil
_v692 = nil
_v698 = nil
r_693 = nil
_v694 = nil
_v695 = nil
_v696 = nil
_v697 = nil
_v887 = nil
_v888 = nil
_v889 = nil
_v890 = nil
_v891 = nil
_v892 = nil
param_893 = nil
_v894 = nil
_v895 = nil
_v896 = nil
_v881 = nil
f_yet_to_run_882 = nil
_v883 = nil
old_exit_884 = nil
new_exit_885 = nil
_v897 = nil
success_898 = nil
_v899 = nil
_v900 = nil
_v999 = nil
_v996 = nil
_v992 = nil
_v988 = nil
_v984 = nil
_v980 = nil
_v977 = nil
_v974 = nil
_v970 = nil
_v967 = nil
_v964 = nil
_v961 = nil
_v958 = nil
_v954 = nil
_v951 = nil
_v948 = nil
_v945 = nil
_v940 = nil
_v936 = nil
_v933 = nil
_v930 = nil
_v926 = nil
_v923 = nil
_v916 = nil
_v917 = nil
_v918 = nil
_v907 = nil
_v908 = nil
_v909 = nil
_v910 = nil
_v911 = nil
_v912 = nil
_v913 = nil
_v903 = nil
str2_868 = nil
fmt2_869 = nil
str1_870 = nil
fmt1_871 = nil
_v873 = nil
_v874 = nil
_v875 = nil
_v876 = nil
_v877 = nil
str_864 = nil
_v858 = nil
_v859 = nil
_v860 = nil
_v853 = nil
_v854 = nil
_v855 = nil
_v848 = nil
_v849 = nil
_v850 = nil
_v843 = nil
_v844 = nil
_v845 = nil
_v839 = nil
_v840 = nil
_v834 = nil
_v835 = nil
_v836 = nil
_v828 = nil
_v829 = nil
_v830 = nil
_v831 = nil
_v824 = nil
_v825 = nil
_v820 = nil
_v821 = nil
_v817 = nil
_v814 = nil
_v811 = nil
_v806 = nil
_v807 = nil
_v808 = nil
_v800 = nil
_v801 = nil
_v802 = nil
_v803 = nil
_v796 = nil
_v797 = nil
_v792 = nil
_v793 = nil
_v789 = nil
_v786 = nil
_v783 = nil
ic_777 = nil
_v780 = nil
_v779 = nil
tl_730 = nil
hd_731 = nil
len_732 = nil
_v733 = nil
_v734 = nil
_v735 = nil
_v736 = nil
_v737 = nil
n_741 = nil
_v742 = nil
_v743 = nil
_v744 = nil
_v745 = nil
_v746 = nil
_v747 = nil
res_748 = nil
_v749 = nil
_v750 = nil
_v751 = nil
_v752 = nil
_v753 = nil
_v754 = nil
_v755 = nil
_v756 = nil
_v757 = nil
len_758 = nil
_v759 = nil
_v760 = nil
_v761 = nil
_v762 = nil
beg_763 = nil
_v764 = nil
_v765 = nil
_v766 = nil
_v767 = nil
_v768 = nil
_v769 = nil
_v770 = nil
build_result_726 = nil
scan_738 = nil
_v771 = nil
_v772 = nil
_v773 = nil
_v774 = nil
s_720 = nil
_v721 = nil
_v722 = nil
_v723 = nil
_v704 = nil
_v705 = nil
_v706 = nil
_v707 = nil
_v708 = nil
len_709 = nil
ofs_710 = nil
s_711 = nil
ic_712 = nil
_v713 = nil
_v715 = nil
_v716 = nil
_v674 = nil
_v675 = nil
_v676 = nil
_v677 = nil
_v678 = nil
len_679 = nil
ofs_680 = nil
s_681 = nil
ic_682 = nil
_v683 = nil
_v685 = nil
_v686 = nil
_v666 = nil
_v668 = nil
_v661 = nil
_v663 = nil
_v656 = nil
c_657 = nil
_v658 = nil
oc_641 = nil
_v651 = nil
_v643 = nil
oc_644 = nil
_v645 = nil
oc_646 = nil
_v647 = nil
_v650 = nil
_v649 = nil
_v637 = nil
_v638 = nil
_v633 = nil
_v634 = nil
_v617 = nil
_v618 = nil
_v619 = nil
_v620 = nil
_v621 = nil
len_622 = nil
ofs_623 = nil
s_624 = nil
oc_625 = nil
_v626 = nil
_v628 = nil
_v629 = nil
_v599 = nil
_v600 = nil
_v601 = nil
_v602 = nil
_v603 = nil
len_604 = nil
ofs_605 = nil
s_606 = nil
oc_607 = nil
_v608 = nil
_v610 = nil
_v611 = nil
_v591 = nil
_v592 = nil
_v593 = nil
_v585 = nil
_v586 = nil
_v587 = nil
l_562 = nil
a_563 = nil
param_564 = nil
l_565 = nil
a_566 = nil
a_567 = nil
_v577 = nil
tag_569 = nil
_v570 = nil
_v571 = nil
param_572 = nil
l_573 = nil
a_574 = nil
_v575 = nil
_v576 = nil
_v578 = nil
iter_560 = nil
_v579 = nil
_v580 = nil
_v581 = nil
_v555 = nil
_v557 = nil
_v550 = nil
_v552 = nil
_v545 = nil
c_546 = nil
_v547 = nil
s_486 = nil
_v491 = nil
_v492 = nil
tag_488 = nil
_v489 = nil
_v490 = nil
_v482 = nil
_v483 = nil
_v461 = nil
_v463 = nil
_v464 = nil
_v465 = nil
_v466 = nil
_v476 = nil
i_467 = nil
match_468 = nil
_v469 = nil
i_470 = nil
match_471 = nil
_v472 = nil
_v473 = nil
_v474 = nil
_v475 = nil
l_458 = nil
loop_459 = nil
_v477 = nil
_v478 = nil
s_449 = nil
_v454 = nil
_v455 = nil
tag_451 = nil
_v452 = nil
_v453 = nil
_v446 = nil
_v437 = nil
_v439 = nil
_v440 = nil
_v427 = nil
_v429 = nil
_v432 = nil
_v433 = nil
_v431 = nil
_v414 = nil
_v415 = nil
n_416 = nil
n_417 = nil
_v419 = nil
l1_402 = nil
l2_403 = nil
_v404 = nil
s_405 = nil
_v406 = nil
_v407 = nil
_v408 = nil
_v409 = nil
_v410 = nil
_v411 = nil
_v380 = nil
_v381 = nil
_v376 = nil
_v377 = nil
_v373 = nil
_v369 = nil
_v351 = nil
_v348 = nil
_v339 = nil
_v342 = nil
match_344 = nil
failwith_345 = nil
invalid_arg_349 = nil
_v352 = nil
_v353 = nil
Exit_355 = nil
min_366 = nil
max_370 = nil
abs_374 = nil
lnot_378 = nil
_v382 = nil
_v383 = nil
max_int_384 = nil
_v385 = nil
min_int_386 = nil
infinity_388 = nil
neg_infinity_390 = nil
nan_392 = nil
max_float_394 = nil
min_float_396 = nil
epsilon_float_398 = nil
symbol_concat_399 = nil
char_of_int_412 = nil
string_of_bool_420 = nil
bool_of_string_424 = nil
bool_of_string_opt_434 = nil
string_of_int_443 = nil
int_of_string_opt_447 = nil
valid_float_lexem_456 = nil
string_of_float_479 = nil
float_of_string_opt_484 = nil
symbol_493 = nil
dps_494 = nil
_v535 = nil
stdin_536 = nil
_v537 = nil
stdout_538 = nil
_v539 = nil
stderr_540 = nil
open_out_gen_541 = nil
open_out_548 = nil
open_out_bin_553 = nil
flush_all_558 = nil
output_bytes_582 = nil
output_string_588 = nil
output_594 = nil
output_substring_612 = nil
output_value_630 = nil
close_out_635 = nil
close_out_noerr_639 = nil
open_in_gen_652 = nil
open_in_659 = nil
open_in_bin_664 = nil
input_669 = nil
unsafe_really_input_687 = nil
really_input_699 = nil
really_input_string_717 = nil
input_line_724 = nil
close_in_noerr_775 = nil
print_char_781 = nil
print_string_784 = nil
print_bytes_787 = nil
print_int_790 = nil
print_float_794 = nil
print_endline_798 = nil
print_newline_804 = nil
prerr_char_809 = nil
prerr_string_812 = nil
prerr_bytes_815 = nil
prerr_int_818 = nil
prerr_float_822 = nil
prerr_endline_826 = nil
prerr_newline_832 = nil
read_line_837 = nil
read_int_841 = nil
read_int_opt_846 = nil
read_float_851 = nil
read_float_opt_856 = nil
LargeFile_861 = nil
string_of_format_862 = nil
symbol_865 = nil
exit_function_878 = nil
at_exit_879 = nil
_v901 = nil
do_domain_local_at_exit_904 = nil
do_at_exit_905 = nil
exit_914 = nil
_v920 = nil
_v921 = nil
_v924 = nil
_v927 = nil
_v931 = nil
_v934 = nil
_v937 = nil
_v941 = nil
_v942 = nil
_v946 = nil
_v949 = nil
_v952 = nil
_v955 = nil
_v959 = nil
_v962 = nil
_v965 = nil
_v968 = nil
_v971 = nil
_v975 = nil
_v978 = nil
_v981 = nil
_v985 = nil
_v989 = nil
_v993 = nil
_v997 = nil
_v1000 = nil
_v1001 = nil
_v1005 = nil
msg_1006 = nil
_v1007 = nil
_v1008 = nil
greet_1002 = nil
_v1010 = nil
_v1011 = nil
_v1012 = nil
x_1013 = nil
_v1014 = nil
_v1016 = nil
_v1017 = nil
_v1029 = nil
_v1030 = nil
greet_1018 = nil
x_1019 = nil
match_1020 = nil
_v1021 = nil
_v1022 = nil
_v1023 = nil
_v1024 = nil
_v1025 = nil
_v1026 = nil
_v1027 = nil
local _m119
local _m192
local _m197
local _m207
local _m217
local _m222
local _m235
local _m256
local _m257
local _m282
local _m302
_m119 = function(param_893, _v894) -- stdlib.ml:567
_v895 = 0
_v896 = old_exit_884(_v895)
return _v896
end
_m192 = function(len_709, ofs_710, s_711, ic_712, _v713) -- stdlib.ml:435
_v715 = invalid_arg_349(_v714)
return _v715
end
_m197 = function(len_679, ofs_680, s_681, ic_682, _v683) -- stdlib.ml:422
_v685 = invalid_arg_349(_v684)
return _v685
end
_m207 = function(oc_644, _v645) -- stdlib.ml:395
local _ok, _res = pcall(function() _v649 = 0
-- stdlib.ml:395
return _v649
end)
if _ok then
exn_648 = _res
else
exn_648 = _res
-- stdlib.ml:395
_v650 = caml_ml_close_channel(oc_644)
-- stdlib.ml:395
end
end
_m217 = function(len_622, ofs_623, s_624, oc_625, _v626) -- stdlib.ml:378
_v628 = invalid_arg_349(_v627)
return _v628
end
_m222 = function(len_604, ofs_605, s_606, oc_607, _v608) -- stdlib.ml:373
_v610 = invalid_arg_349(_v609)
return _v610
end
_m235 = function(param_572, l_573, a_574, _v575) -- stdlib.ml:355
_v576 = iter_560(l_573)
return _v576
end
_m256 = function(i_467, match_468, _v469) -- stdlib.ml:283
return s_457
end
_m257 = function(i_470, match_471, _v472) -- stdlib.ml:282
_v473 = 2
_v474 = int_add(i_470, _v473)
_v475 = loop_459(_v474)
return _v475
end
_m282 = function(n_416, n_417) -- stdlib.ml:224
_v419 = invalid_arg_349(_v418)
return _v419
end
_m302 = function(greet_1018, x_1019, match_1020) _v1021 = {0, greet_1018}
_v1022 = 0
_v1023 = 0
_v1024 = _v1000[104]
-- std_exit.ml:18
_v1025 = _v1024(_v1023)
-- std_exit.ml:18
_v1026 = {0}
_v1027 = 0
return
end
Out_of_memory_359 = {248, "Out_of_memory", -2}
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
_v1004 = "hello "
_v1009 = "world"
_v1015 = "ok"
_v1028 = "no"
_v1042 = caml_register_global(22, Undefined_recursive_module_365, "")
_v1041 = caml_register_global(20, Assert_failure_357, "")
_v1040 = caml_register_global(18, Sys_blocked_io_364, "")
_v1039 = caml_register_global(16, Stack_overflow_360, "")
_v1038 = caml_register_global(14, Match_failure_356, "")
_v1037 = caml_register_global(12, Not_found_358, "")
_v1036 = caml_register_global(10, Division_by_zero_363, "")
_v1035 = caml_register_global(8, End_of_file_362, "")
_v1034 = caml_register_global(6, Invalid_argument_341, "")
_v1033 = caml_register_global(4, Failure_347, "")
_v1032 = caml_register_global(2, Sys_error_361, "")
_v1031 = caml_register_global(0, Out_of_memory_359, "")
erase_rel_1 = function(param_2) -- camlinternalFormatBasics.ml:562
local _m119
local _m192
local _m197
local _m207
local _m217
local _m222
local _m235
local _m256
local _m257
local _m282
local _m302
_m119 = function(param_893, _v894) -- stdlib.ml:567
_v895 = 0
_v896 = old_exit_884(_v895)
return _v896
end
_m192 = function(len_709, ofs_710, s_711, ic_712, _v713) -- stdlib.ml:435
_v715 = invalid_arg_349(_v714)
return _v715
end
_m197 = function(len_679, ofs_680, s_681, ic_682, _v683) -- stdlib.ml:422
_v685 = invalid_arg_349(_v684)
return _v685
end
_m207 = function(oc_644, _v645) -- stdlib.ml:395
local _ok, _res = pcall(function() _v649 = 0
-- stdlib.ml:395
return _v649
end)
if _ok then
exn_648 = _res
else
exn_648 = _res
-- stdlib.ml:395
_v650 = caml_ml_close_channel(oc_644)
-- stdlib.ml:395
end
end
_m217 = function(len_622, ofs_623, s_624, oc_625, _v626) -- stdlib.ml:378
_v628 = invalid_arg_349(_v627)
return _v628
end
_m222 = function(len_604, ofs_605, s_606, oc_607, _v608) -- stdlib.ml:373
_v610 = invalid_arg_349(_v609)
return _v610
end
_m235 = function(param_572, l_573, a_574, _v575) -- stdlib.ml:355
_v576 = iter_560(l_573)
return _v576
end
_m256 = function(i_467, match_468, _v469) -- stdlib.ml:283
return s_457
end
_m257 = function(i_470, match_471, _v472) -- stdlib.ml:282
_v473 = 2
_v474 = int_add(i_470, _v473)
_v475 = loop_459(_v474)
return _v475
end
_m282 = function(n_416, n_417) -- stdlib.ml:224
_v419 = invalid_arg_349(_v418)
return _v419
end
_m302 = function(greet_1018, x_1019, match_1020) _v1021 = {0, greet_1018}
_v1022 = 0
_v1023 = 0
_v1024 = _v1000[104]
-- std_exit.ml:18
_v1025 = _v1024(_v1023)
-- std_exit.ml:18
_v1026 = {0}
_v1027 = 0
return
end
-- camlinternalFormatBasics.ml:528
_v52 = type(param_2) == "number"
if _v52 then
if param_2 == 0 then
-- camlinternalFormatBasics.ml:562
_v3 = 0
return _v3
end
else
_v51 = direct_obj_tag(param_2)
if _v51 == 0 then
rest_4 = param_2[2]
-- camlinternalFormatBasics.ml:533
_v5 = erase_rel_1(rest_4)
-- camlinternalFormatBasics.ml:533
_v6 = {0, _v5}
return _v6
end
if _v51 == 1 then
rest_7 = param_2[2]
-- camlinternalFormatBasics.ml:535
_v8 = erase_rel_1(rest_7)
-- camlinternalFormatBasics.ml:535
_v9 = {1, _v8}
return _v9
end
if _v51 == 2 then
rest_10 = param_2[2]
-- camlinternalFormatBasics.ml:537
_v11 = erase_rel_1(rest_10)
-- camlinternalFormatBasics.ml:537
_v12 = {2, _v11}
return _v12
end
if _v51 == 3 then
rest_13 = param_2[2]
-- camlinternalFormatBasics.ml:539
_v14 = erase_rel_1(rest_13)
-- camlinternalFormatBasics.ml:539
_v15 = {3, _v14}
return _v15
end
if _v51 == 4 then
rest_16 = param_2[2]
-- camlinternalFormatBasics.ml:543
_v17 = erase_rel_1(rest_16)
-- camlinternalFormatBasics.ml:543
_v18 = {4, _v17}
return _v18
end
if _v51 == 5 then
rest_19 = param_2[2]
-- camlinternalFormatBasics.ml:541
_v20 = erase_rel_1(rest_19)
-- camlinternalFormatBasics.ml:541
_v21 = {5, _v20}
return _v21
end
if _v51 == 6 then
rest_22 = param_2[2]
-- camlinternalFormatBasics.ml:545
_v23 = erase_rel_1(rest_22)
-- camlinternalFormatBasics.ml:545
_v24 = {6, _v23}
return _v24
end
if _v51 == 7 then
rest_25 = param_2[2]
-- camlinternalFormatBasics.ml:547
_v26 = erase_rel_1(rest_25)
-- camlinternalFormatBasics.ml:547
_v27 = {7, _v26}
return _v27
end
if _v51 == 8 then
rest_28 = param_2[3]
ty_29 = param_2[2]
-- camlinternalFormatBasics.ml:549
_v30 = erase_rel_1(rest_28)
-- camlinternalFormatBasics.ml:549
_v31 = {8, ty_29, _v30}
return _v31
end
if _v51 == 9 then
rest_32 = param_2[4]
ty1_33 = param_2[2]
-- camlinternalFormatBasics.ml:551
_v34 = erase_rel_1(rest_32)
-- camlinternalFormatBasics.ml:551
_v35 = {9, ty1_33, ty1_33, _v34}
return _v35
end
if _v51 == 10 then
rest_36 = param_2[2]
-- camlinternalFormatBasics.ml:553
_v37 = erase_rel_1(rest_36)
-- camlinternalFormatBasics.ml:553
_v38 = {10, _v37}
return _v38
end
if _v51 == 11 then
rest_39 = param_2[2]
-- camlinternalFormatBasics.ml:555
_v40 = erase_rel_1(rest_39)
-- camlinternalFormatBasics.ml:555
_v41 = {11, _v40}
return _v41
end
if _v51 == 12 then
rest_42 = param_2[2]
-- camlinternalFormatBasics.ml:557
_v43 = erase_rel_1(rest_42)
-- camlinternalFormatBasics.ml:557
_v44 = {12, _v43}
return _v44
end
if _v51 == 13 then
rest_45 = param_2[2]
-- camlinternalFormatBasics.ml:559
_v46 = erase_rel_1(rest_45)
-- camlinternalFormatBasics.ml:559
_v47 = {13, _v46}
return _v47
end
if _v51 == 14 then
rest_48 = param_2[2]
-- camlinternalFormatBasics.ml:561
_v49 = erase_rel_1(rest_48)
-- camlinternalFormatBasics.ml:561
_v50 = {14, _v49}
return _v50
end
end
end
concat_fmtty_53 = function(fmtty1_55, fmtty2_54) -- camlinternalFormatBasics.ml:621
local _m119
local _m192
local _m197
local _m207
local _m217
local _m222
local _m235
local _m256
local _m257
local _m282
local _m302
_m119 = function(param_893, _v894) -- stdlib.ml:567
_v895 = 0
_v896 = old_exit_884(_v895)
return _v896
end
_m192 = function(len_709, ofs_710, s_711, ic_712, _v713) -- stdlib.ml:435
_v715 = invalid_arg_349(_v714)
return _v715
end
_m197 = function(len_679, ofs_680, s_681, ic_682, _v683) -- stdlib.ml:422
_v685 = invalid_arg_349(_v684)
return _v685
end
_m207 = function(oc_644, _v645) -- stdlib.ml:395
local _ok, _res = pcall(function() _v649 = 0
-- stdlib.ml:395
return _v649
end)
if _ok then
exn_648 = _res
else
exn_648 = _res
-- stdlib.ml:395
_v650 = caml_ml_close_channel(oc_644)
-- stdlib.ml:395
end
end
_m217 = function(len_622, ofs_623, s_624, oc_625, _v626) -- stdlib.ml:378
_v628 = invalid_arg_349(_v627)
return _v628
end
_m222 = function(len_604, ofs_605, s_606, oc_607, _v608) -- stdlib.ml:373
_v610 = invalid_arg_349(_v609)
return _v610
end
_m235 = function(param_572, l_573, a_574, _v575) -- stdlib.ml:355
_v576 = iter_560(l_573)
return _v576
end
_m256 = function(i_467, match_468, _v469) -- stdlib.ml:283
return s_457
end
_m257 = function(i_470, match_471, _v472) -- stdlib.ml:282
_v473 = 2
_v474 = int_add(i_470, _v473)
_v475 = loop_459(_v474)
return _v475
end
_m282 = function(n_416, n_417) -- stdlib.ml:224
_v419 = invalid_arg_349(_v418)
return _v419
end
_m302 = function(greet_1018, x_1019, match_1020) _v1021 = {0, greet_1018}
_v1022 = 0
_v1023 = 0
_v1024 = _v1000[104]
-- std_exit.ml:18
_v1025 = _v1024(_v1023)
-- std_exit.ml:18
_v1026 = {0}
_v1027 = 0
return
end
-- camlinternalFormatBasics.ml:590
_v105 = type(fmtty1_55) == "number"
if _v105 then
if fmtty1_55 == 0 then
-- camlinternalFormatBasics.ml:621
return fmtty2_54
end
else
_v104 = direct_obj_tag(fmtty1_55)
if _v104 == 0 then
rest_56 = fmtty1_55[2]
-- camlinternalFormatBasics.ml:592
_v57 = concat_fmtty_53(rest_56, fmtty2_54)
-- camlinternalFormatBasics.ml:592
_v58 = {0, _v57}
return _v58
end
if _v104 == 1 then
rest_59 = fmtty1_55[2]
-- camlinternalFormatBasics.ml:594
_v60 = concat_fmtty_53(rest_59, fmtty2_54)
-- camlinternalFormatBasics.ml:594
_v61 = {1, _v60}
return _v61
end
if _v104 == 2 then
rest_62 = fmtty1_55[2]
-- camlinternalFormatBasics.ml:596
_v63 = concat_fmtty_53(rest_62, fmtty2_54)
-- camlinternalFormatBasics.ml:596
_v64 = {2, _v63}
return _v64
end
if _v104 == 3 then
rest_65 = fmtty1_55[2]
-- camlinternalFormatBasics.ml:598
_v66 = concat_fmtty_53(rest_65, fmtty2_54)
-- camlinternalFormatBasics.ml:598
_v67 = {3, _v66}
return _v67
end
if _v104 == 4 then
rest_68 = fmtty1_55[2]
-- camlinternalFormatBasics.ml:600
_v69 = concat_fmtty_53(rest_68, fmtty2_54)
-- camlinternalFormatBasics.ml:600
_v70 = {4, _v69}
return _v70
end
if _v104 == 5 then
rest_71 = fmtty1_55[2]
-- camlinternalFormatBasics.ml:602
_v72 = concat_fmtty_53(rest_71, fmtty2_54)
-- camlinternalFormatBasics.ml:602
_v73 = {5, _v72}
return _v73
end
if _v104 == 6 then
rest_74 = fmtty1_55[2]
-- camlinternalFormatBasics.ml:604
_v75 = concat_fmtty_53(rest_74, fmtty2_54)
-- camlinternalFormatBasics.ml:604
_v76 = {6, _v75}
return _v76
end
if _v104 == 7 then
rest_77 = fmtty1_55[2]
-- camlinternalFormatBasics.ml:606
_v78 = concat_fmtty_53(rest_77, fmtty2_54)
-- camlinternalFormatBasics.ml:606
_v79 = {7, _v78}
return _v79
end
if _v104 == 8 then
rest_80 = fmtty1_55[3]
ty_81 = fmtty1_55[2]
-- camlinternalFormatBasics.ml:618
_v82 = concat_fmtty_53(rest_80, fmtty2_54)
-- camlinternalFormatBasics.ml:618
_v83 = {8, ty_81, _v82}
return _v83
end
if _v104 == 9 then
rest_84 = fmtty1_55[4]
ty2_85 = fmtty1_55[3]
ty1_86 = fmtty1_55[2]
-- camlinternalFormatBasics.ml:620
_v87 = concat_fmtty_53(rest_84, fmtty2_54)
-- camlinternalFormatBasics.ml:620
_v88 = {9, ty1_86, ty2_85, _v87}
return _v88
end
if _v104 == 10 then
rest_89 = fmtty1_55[2]
-- camlinternalFormatBasics.ml:608
_v90 = concat_fmtty_53(rest_89, fmtty2_54)
-- camlinternalFormatBasics.ml:608
_v91 = {10, _v90}
return _v91
end
if _v104 == 11 then
rest_92 = fmtty1_55[2]
-- camlinternalFormatBasics.ml:610
_v93 = concat_fmtty_53(rest_92, fmtty2_54)
-- camlinternalFormatBasics.ml:610
_v94 = {11, _v93}
return _v94
end
if _v104 == 12 then
rest_95 = fmtty1_55[2]
-- camlinternalFormatBasics.ml:612
_v96 = concat_fmtty_53(rest_95, fmtty2_54)
-- camlinternalFormatBasics.ml:612
_v97 = {12, _v96}
return _v97
end
if _v104 == 13 then
rest_98 = fmtty1_55[2]
-- camlinternalFormatBasics.ml:614
_v99 = concat_fmtty_53(rest_98, fmtty2_54)
-- camlinternalFormatBasics.ml:614
_v100 = {13, _v99}
return _v100
end
if _v104 == 14 then
rest_101 = fmtty1_55[2]
-- camlinternalFormatBasics.ml:616
_v102 = concat_fmtty_53(rest_101, fmtty2_54)
-- camlinternalFormatBasics.ml:616
_v103 = {14, _v102}
return _v103
end
end
end
concat_fmt_106 = function(fmt1_108, fmt2_107) -- camlinternalFormatBasics.ml:690
local _m119
local _m192
local _m197
local _m207
local _m217
local _m222
local _m235
local _m256
local _m257
local _m282
local _m302
_m119 = function(param_893, _v894) -- stdlib.ml:567
_v895 = 0
_v896 = old_exit_884(_v895)
return _v896
end
_m192 = function(len_709, ofs_710, s_711, ic_712, _v713) -- stdlib.ml:435
_v715 = invalid_arg_349(_v714)
return _v715
end
_m197 = function(len_679, ofs_680, s_681, ic_682, _v683) -- stdlib.ml:422
_v685 = invalid_arg_349(_v684)
return _v685
end
_m207 = function(oc_644, _v645) -- stdlib.ml:395
local _ok, _res = pcall(function() _v649 = 0
-- stdlib.ml:395
return _v649
end)
if _ok then
exn_648 = _res
else
exn_648 = _res
-- stdlib.ml:395
_v650 = caml_ml_close_channel(oc_644)
-- stdlib.ml:395
end
end
_m217 = function(len_622, ofs_623, s_624, oc_625, _v626) -- stdlib.ml:378
_v628 = invalid_arg_349(_v627)
return _v628
end
_m222 = function(len_604, ofs_605, s_606, oc_607, _v608) -- stdlib.ml:373
_v610 = invalid_arg_349(_v609)
return _v610
end
_m235 = function(param_572, l_573, a_574, _v575) -- stdlib.ml:355
_v576 = iter_560(l_573)
return _v576
end
_m256 = function(i_467, match_468, _v469) -- stdlib.ml:283
return s_457
end
_m257 = function(i_470, match_471, _v472) -- stdlib.ml:282
_v473 = 2
_v474 = int_add(i_470, _v473)
_v475 = loop_459(_v474)
return _v475
end
_m282 = function(n_416, n_417) -- stdlib.ml:224
_v419 = invalid_arg_349(_v418)
return _v419
end
_m302 = function(greet_1018, x_1019, match_1020) _v1021 = {0, greet_1018}
_v1022 = 0
_v1023 = 0
_v1024 = _v1000[104]
-- std_exit.ml:18
_v1025 = _v1024(_v1023)
-- std_exit.ml:18
_v1026 = {0}
_v1027 = 0
return
end
-- camlinternalFormatBasics.ml:631
_v217 = type(fmt1_108) == "number"
if _v217 then
if fmt1_108 == 0 then
-- camlinternalFormatBasics.ml:690
return fmt2_107
end
else
_v216 = direct_obj_tag(fmt1_108)
if _v216 == 0 then
rest_109 = fmt1_108[2]
-- camlinternalFormatBasics.ml:649
_v110 = concat_fmt_106(rest_109, fmt2_107)
-- camlinternalFormatBasics.ml:649
_v111 = {0, _v110}
return _v111
end
if _v216 == 1 then
rest_112 = fmt1_108[2]
-- camlinternalFormatBasics.ml:651
_v113 = concat_fmt_106(rest_112, fmt2_107)
-- camlinternalFormatBasics.ml:651
_v114 = {1, _v113}
return _v114
end
if _v216 == 2 then
rest_115 = fmt1_108[3]
pad_116 = fmt1_108[2]
-- camlinternalFormatBasics.ml:633
_v117 = concat_fmt_106(rest_115, fmt2_107)
-- camlinternalFormatBasics.ml:633
_v118 = {2, pad_116, _v117}
return _v118
end
if _v216 == 3 then
rest_119 = fmt1_108[3]
pad_120 = fmt1_108[2]
-- camlinternalFormatBasics.ml:635
_v121 = concat_fmt_106(rest_119, fmt2_107)
-- camlinternalFormatBasics.ml:635
_v122 = {3, pad_120, _v121}
return _v122
end
if _v216 == 4 then
rest_123 = fmt1_108[5]
prec_124 = fmt1_108[4]
pad_125 = fmt1_108[3]
iconv_126 = fmt1_108[2]
-- camlinternalFormatBasics.ml:638
_v127 = concat_fmt_106(rest_123, fmt2_107)
-- camlinternalFormatBasics.ml:638
_v128 = {4, iconv_126, pad_125, prec_124, _v127}
return _v128
end
if _v216 == 5 then
rest_129 = fmt1_108[5]
prec_130 = fmt1_108[4]
pad_131 = fmt1_108[3]
iconv_132 = fmt1_108[2]
-- camlinternalFormatBasics.ml:640
_v133 = concat_fmt_106(rest_129, fmt2_107)
-- camlinternalFormatBasics.ml:640
_v134 = {5, iconv_132, pad_131, prec_130, _v133}
return _v134
end
if _v216 == 6 then
rest_135 = fmt1_108[5]
prec_136 = fmt1_108[4]
pad_137 = fmt1_108[3]
iconv_138 = fmt1_108[2]
-- camlinternalFormatBasics.ml:642
_v139 = concat_fmt_106(rest_135, fmt2_107)
-- camlinternalFormatBasics.ml:642
_v140 = {6, iconv_138, pad_137, prec_136, _v139}
return _v140
end
if _v216 == 7 then
rest_141 = fmt1_108[5]
prec_142 = fmt1_108[4]
pad_143 = fmt1_108[3]
iconv_144 = fmt1_108[2]
-- camlinternalFormatBasics.ml:644
_v145 = concat_fmt_106(rest_141, fmt2_107)
-- camlinternalFormatBasics.ml:644
_v146 = {7, iconv_144, pad_143, prec_142, _v145}
return _v146
end
if _v216 == 8 then
rest_147 = fmt1_108[5]
prec_148 = fmt1_108[4]
pad_149 = fmt1_108[3]
fconv_150 = fmt1_108[2]
-- camlinternalFormatBasics.ml:646
_v151 = concat_fmt_106(rest_147, fmt2_107)
-- camlinternalFormatBasics.ml:646
_v152 = {8, fconv_150, pad_149, prec_148, _v151}
return _v152
end
if _v216 == 9 then
rest_153 = fmt1_108[3]
pad_154 = fmt1_108[2]
-- camlinternalFormatBasics.ml:653
_v155 = concat_fmt_106(rest_153, fmt2_107)
-- camlinternalFormatBasics.ml:653
_v156 = {9, pad_154, _v155}
return _v156
end
if _v216 == 10 then
rest_157 = fmt1_108[2]
-- camlinternalFormatBasics.ml:663
_v158 = concat_fmt_106(rest_157, fmt2_107)
-- camlinternalFormatBasics.ml:663
_v159 = {10, _v158}
return _v159
end
if _v216 == 11 then
rest_160 = fmt1_108[3]
str_161 = fmt1_108[2]
-- camlinternalFormatBasics.ml:666
_v162 = concat_fmt_106(rest_160, fmt2_107)
-- camlinternalFormatBasics.ml:666
_v163 = {11, str_161, _v162}
return _v163
end
if _v216 == 12 then
rest_164 = fmt1_108[3]
chr_165 = fmt1_108[2]
-- camlinternalFormatBasics.ml:668
_v166 = concat_fmt_106(rest_164, fmt2_107)
-- camlinternalFormatBasics.ml:668
_v167 = {12, chr_165, _v166}
return _v167
end
if _v216 == 13 then
rest_168 = fmt1_108[4]
fmtty_169 = fmt1_108[3]
pad_170 = fmt1_108[2]
-- camlinternalFormatBasics.ml:671
_v171 = concat_fmt_106(rest_168, fmt2_107)
-- camlinternalFormatBasics.ml:671
_v172 = {13, pad_170, fmtty_169, _v171}
return _v172
end
if _v216 == 14 then
rest_173 = fmt1_108[4]
fmtty_174 = fmt1_108[3]
pad_175 = fmt1_108[2]
-- camlinternalFormatBasics.ml:673
_v176 = concat_fmt_106(rest_173, fmt2_107)
-- camlinternalFormatBasics.ml:673
_v177 = {14, pad_175, fmtty_174, _v176}
return _v177
end
if _v216 == 15 then
rest_178 = fmt1_108[2]
-- camlinternalFormatBasics.ml:655
_v179 = concat_fmt_106(rest_178, fmt2_107)
-- camlinternalFormatBasics.ml:655
_v180 = {15, _v179}
return _v180
end
if _v216 == 16 then
rest_181 = fmt1_108[2]
-- camlinternalFormatBasics.ml:657
_v182 = concat_fmt_106(rest_181, fmt2_107)
-- camlinternalFormatBasics.ml:657
_v183 = {16, _v182}
return _v183
end
if _v216 == 17 then
rest_184 = fmt1_108[3]
fmting_lit_185 = fmt1_108[2]
-- camlinternalFormatBasics.ml:685
_v186 = concat_fmt_106(rest_184, fmt2_107)
-- camlinternalFormatBasics.ml:685
_v187 = {17, fmting_lit_185, _v186}
return _v187
end
if _v216 == 18 then
rest_188 = fmt1_108[3]
fmting_gen_189 = fmt1_108[2]
-- camlinternalFormatBasics.ml:687
_v190 = concat_fmt_106(rest_188, fmt2_107)
-- camlinternalFormatBasics.ml:687
_v191 = {18, fmting_gen_189, _v190}
return _v191
end
if _v216 == 19 then
rest_192 = fmt1_108[2]
-- camlinternalFormatBasics.ml:661
_v193 = concat_fmt_106(rest_192, fmt2_107)
-- camlinternalFormatBasics.ml:661
_v194 = {19, _v193}
return _v194
end
if _v216 == 20 then
rest_195 = fmt1_108[4]
char_set_196 = fmt1_108[3]
width_opt_197 = fmt1_108[2]
-- camlinternalFormatBasics.ml:676
_v198 = concat_fmt_106(rest_195, fmt2_107)
-- camlinternalFormatBasics.ml:676
_v199 = {20, width_opt_197, char_set_196, _v198}
return _v199
end
if _v216 == 21 then
rest_200 = fmt1_108[3]
counter_201 = fmt1_108[2]
-- camlinternalFormatBasics.ml:678
_v202 = concat_fmt_106(rest_200, fmt2_107)
-- camlinternalFormatBasics.ml:678
_v203 = {21, counter_201, _v202}
return _v203
end
if _v216 == 22 then
rest_204 = fmt1_108[2]
-- camlinternalFormatBasics.ml:680
_v205 = concat_fmt_106(rest_204, fmt2_107)
-- camlinternalFormatBasics.ml:680
_v206 = {22, _v205}
return _v206
end
if _v216 == 23 then
rest_207 = fmt1_108[3]
ign_208 = fmt1_108[2]
-- camlinternalFormatBasics.ml:682
_v209 = concat_fmt_106(rest_207, fmt2_107)
-- camlinternalFormatBasics.ml:682
_v210 = {23, ign_208, _v209}
return _v210
end
if _v216 == 24 then
rest_211 = fmt1_108[4]
f_212 = fmt1_108[3]
arity_213 = fmt1_108[2]
-- camlinternalFormatBasics.ml:659
_v214 = concat_fmt_106(rest_211, fmt2_107)
-- camlinternalFormatBasics.ml:659
_v215 = {24, arity_213, f_212, _v214}
return _v215
end
end
end
string_concat_map_218 = function(f_220, param_219) -- camlinternalFormatBasics.ml:749
local _m119
local _m192
local _m197
local _m207
local _m217
local _m222
local _m235
local _m256
local _m257
local _m282
local _m302
_m119 = function(param_893, _v894) -- stdlib.ml:567
_v895 = 0
_v896 = old_exit_884(_v895)
return _v896
end
_m192 = function(len_709, ofs_710, s_711, ic_712, _v713) -- stdlib.ml:435
_v715 = invalid_arg_349(_v714)
return _v715
end
_m197 = function(len_679, ofs_680, s_681, ic_682, _v683) -- stdlib.ml:422
_v685 = invalid_arg_349(_v684)
return _v685
end
_m207 = function(oc_644, _v645) -- stdlib.ml:395
local _ok, _res = pcall(function() _v649 = 0
-- stdlib.ml:395
return _v649
end)
if _ok then
exn_648 = _res
else
exn_648 = _res
-- stdlib.ml:395
_v650 = caml_ml_close_channel(oc_644)
-- stdlib.ml:395
end
end
_m217 = function(len_622, ofs_623, s_624, oc_625, _v626) -- stdlib.ml:378
_v628 = invalid_arg_349(_v627)
return _v628
end
_m222 = function(len_604, ofs_605, s_606, oc_607, _v608) -- stdlib.ml:373
_v610 = invalid_arg_349(_v609)
return _v610
end
_m235 = function(param_572, l_573, a_574, _v575) -- stdlib.ml:355
_v576 = iter_560(l_573)
return _v576
end
_m256 = function(i_467, match_468, _v469) -- stdlib.ml:283
return s_457
end
_m257 = function(i_470, match_471, _v472) -- stdlib.ml:282
_v473 = 2
_v474 = int_add(i_470, _v473)
_v475 = loop_459(_v474)
return _v475
end
_m282 = function(n_416, n_417) -- stdlib.ml:224
_v419 = invalid_arg_349(_v418)
return _v419
end
_m302 = function(greet_1018, x_1019, match_1020) _v1021 = {0, greet_1018}
_v1022 = 0
_v1023 = 0
_v1024 = _v1000[104]
-- std_exit.ml:18
_v1025 = _v1024(_v1023)
-- std_exit.ml:18
_v1026 = {0}
_v1027 = 0
return
end
-- camlinternalFormatBasics.ml:699
_v336 = type(param_219) == "number"
if _v336 then
if param_219 == 0 then
-- camlinternalFormatBasics.ml:749
_v221 = 0
return _v221
end
else
_v335 = direct_obj_tag(param_219)
if _v335 == 0 then
rest_222 = param_219[2]
-- camlinternalFormatBasics.ml:716
_v223 = string_concat_map_218(f_220, rest_222)
-- camlinternalFormatBasics.ml:716
_v224 = {0, _v223}
return _v224
end
if _v335 == 1 then
rest_225 = param_219[2]
-- camlinternalFormatBasics.ml:718
_v226 = string_concat_map_218(f_220, rest_225)
-- camlinternalFormatBasics.ml:718
_v227 = {1, _v226}
return _v227
end
if _v335 == 2 then
rest_228 = param_219[3]
pad_229 = param_219[2]
-- camlinternalFormatBasics.ml:702
_v230 = string_concat_map_218(f_220, rest_228)
-- camlinternalFormatBasics.ml:702
_v231 = {2, pad_229, _v230}
return _v231
end
if _v335 == 3 then
rest_232 = param_219[3]
pad_233 = param_219[2]
-- camlinternalFormatBasics.ml:703
_v234 = string_concat_map_218(f_220, rest_232)
-- camlinternalFormatBasics.ml:703
_v235 = {3, pad_233, _v234}
return _v235
end
if _v335 == 4 then
rest_236 = param_219[5]
prec_237 = param_219[4]
pad_238 = param_219[3]
iconv_239 = param_219[2]
-- camlinternalFormatBasics.ml:706
_v240 = string_concat_map_218(f_220, rest_236)
-- camlinternalFormatBasics.ml:706
_v241 = {4, iconv_239, pad_238, prec_237, _v240}
return _v241
end
if _v335 == 5 then
rest_242 = param_219[5]
prec_243 = param_219[4]
pad_244 = param_219[3]
iconv_245 = param_219[2]
-- camlinternalFormatBasics.ml:708
_v246 = string_concat_map_218(f_220, rest_242)
-- camlinternalFormatBasics.ml:708
_v247 = {5, iconv_245, pad_244, prec_243, _v246}
return _v247
end
if _v335 == 6 then
rest_248 = param_219[5]
prec_249 = param_219[4]
pad_250 = param_219[3]
iconv_251 = param_219[2]
-- camlinternalFormatBasics.ml:710
_v252 = string_concat_map_218(f_220, rest_248)
-- camlinternalFormatBasics.ml:710
_v253 = {6, iconv_251, pad_250, prec_249, _v252}
return _v253
end
if _v335 == 7 then
rest_254 = param_219[5]
prec_255 = param_219[4]
pad_256 = param_219[3]
iconv_257 = param_219[2]
-- camlinternalFormatBasics.ml:712
_v258 = string_concat_map_218(f_220, rest_254)
-- camlinternalFormatBasics.ml:712
_v259 = {7, iconv_257, pad_256, prec_255, _v258}
return _v259
end
if _v335 == 8 then
rest_260 = param_219[5]
prec_261 = param_219[4]
pad_262 = param_219[3]
fconv_263 = param_219[2]
-- camlinternalFormatBasics.ml:714
_v264 = string_concat_map_218(f_220, rest_260)
-- camlinternalFormatBasics.ml:714
_v265 = {8, fconv_263, pad_262, prec_261, _v264}
return _v265
end
if _v335 == 9 then
rest_266 = param_219[3]
pad_267 = param_219[2]
-- camlinternalFormatBasics.ml:719
_v268 = string_concat_map_218(f_220, rest_266)
-- camlinternalFormatBasics.ml:719
_v269 = {9, pad_267, _v268}
return _v269
end
if _v335 == 10 then
rest_270 = param_219[2]
-- camlinternalFormatBasics.ml:725
_v271 = string_concat_map_218(f_220, rest_270)
-- camlinternalFormatBasics.ml:725
_v272 = {10, _v271}
return _v272
end
if _v335 == 11 then
rest_273 = param_219[3]
str_274 = param_219[2]
-- camlinternalFormatBasics.ml:727
_v275 = string_concat_map_218(f_220, rest_273)
-- camlinternalFormatBasics.ml:727
_v276 = -1953941022
_v277 = {0, _v276, str_274}
_v278 = f_220[2]
_v279 = _v278(_v277, _v275)
return _v279
end
if _v335 == 12 then
rest_280 = param_219[3]
chr_281 = param_219[2]
-- camlinternalFormatBasics.ml:729
_v282 = string_concat_map_218(f_220, rest_280)
-- camlinternalFormatBasics.ml:729
_v283 = 1496389100
_v284 = {0, _v283, chr_281}
_v285 = f_220[2]
_v286 = _v285(_v284, _v282)
return _v286
end
if _v335 == 13 then
rest_287 = param_219[4]
fmtty_288 = param_219[3]
pad_289 = param_219[2]
-- camlinternalFormatBasics.ml:731
_v290 = string_concat_map_218(f_220, rest_287)
-- camlinternalFormatBasics.ml:731
_v291 = {13, pad_289, fmtty_288, _v290}
return _v291
end
if _v335 == 14 then
rest_292 = param_219[4]
fmtty_293 = param_219[3]
pad_294 = param_219[2]
-- camlinternalFormatBasics.ml:733
_v295 = string_concat_map_218(f_220, rest_292)
-- camlinternalFormatBasics.ml:733
_v296 = {14, pad_294, fmtty_293, _v295}
return _v296
end
if _v335 == 15 then
rest_297 = param_219[2]
-- camlinternalFormatBasics.ml:720
_v298 = string_concat_map_218(f_220, rest_297)
-- camlinternalFormatBasics.ml:720
_v299 = {15, _v298}
return _v299
end
if _v335 == 16 then
rest_300 = param_219[2]
-- camlinternalFormatBasics.ml:721
_v301 = string_concat_map_218(f_220, rest_300)
-- camlinternalFormatBasics.ml:721
_v302 = {16, _v301}
return _v302
end
if _v335 == 17 then
rest_303 = param_219[3]
fmting_lit_304 = param_219[2]
-- camlinternalFormatBasics.ml:745
_v305 = string_concat_map_218(f_220, rest_303)
-- camlinternalFormatBasics.ml:745
_v306 = {17, fmting_lit_304, _v305}
return _v306
end
if _v335 == 18 then
rest_307 = param_219[3]
fmting_gen_308 = param_219[2]
-- camlinternalFormatBasics.ml:747
_v309 = string_concat_map_218(f_220, rest_307)
-- camlinternalFormatBasics.ml:747
_v310 = {18, fmting_gen_308, _v309}
return _v310
end
if _v335 == 19 then
rest_311 = param_219[2]
-- camlinternalFormatBasics.ml:724
_v312 = string_concat_map_218(f_220, rest_311)
-- camlinternalFormatBasics.ml:724
_v313 = {19, _v312}
return _v313
end
if _v335 == 20 then
rest_314 = param_219[4]
char_set_315 = param_219[3]
width_opt_316 = param_219[2]
-- camlinternalFormatBasics.ml:736
_v317 = string_concat_map_218(f_220, rest_314)
-- camlinternalFormatBasics.ml:736
_v318 = {20, width_opt_316, char_set_315, _v317}
return _v318
end
if _v335 == 21 then
rest_319 = param_219[3]
counter_320 = param_219[2]
-- camlinternalFormatBasics.ml:738
_v321 = string_concat_map_218(f_220, rest_319)
-- camlinternalFormatBasics.ml:738
_v322 = {21, counter_320, _v321}
return _v322
end
if _v335 == 22 then
rest_323 = param_219[2]
-- camlinternalFormatBasics.ml:740
_v324 = string_concat_map_218(f_220, rest_323)
-- camlinternalFormatBasics.ml:740
_v325 = {22, _v324}
return _v325
end
if _v335 == 23 then
rest_326 = param_219[3]
ign_327 = param_219[2]
-- camlinternalFormatBasics.ml:742
_v328 = string_concat_map_218(f_220, rest_326)
-- camlinternalFormatBasics.ml:742
_v329 = {23, ign_327, _v328}
return _v329
end
if _v335 == 24 then
rest_330 = param_219[4]
fc_331 = param_219[3]
arity_332 = param_219[2]
-- camlinternalFormatBasics.ml:723
_v333 = string_concat_map_218(f_220, rest_330)
-- camlinternalFormatBasics.ml:723
_v334 = {24, arity_332, fc_331, _v333}
return _v334
end
end
end
_v337 = {0, concat_fmtty_53, erase_rel_1, concat_fmt_106, string_concat_map_218}
_v338 = 0
_v339 = 398
_v342 = {0, Invalid_argument_341, _v340}
-- stdlib.ml:23
match_344 = caml_register_named_value(_v343, _v342)
-- stdlib.ml:24
failwith_345 = function(s_346) -- stdlib.ml:29
local _m119
local _m192
local _m197
local _m207
local _m217
local _m222
local _m235
local _m256
local _m257
local _m282
local _m302
_m119 = function(param_893, _v894) -- stdlib.ml:567
_v895 = 0
_v896 = old_exit_884(_v895)
return _v896
end
_m192 = function(len_709, ofs_710, s_711, ic_712, _v713) -- stdlib.ml:435
_v715 = invalid_arg_349(_v714)
return _v715
end
_m197 = function(len_679, ofs_680, s_681, ic_682, _v683) -- stdlib.ml:422
_v685 = invalid_arg_349(_v684)
return _v685
end
_m207 = function(oc_644, _v645) -- stdlib.ml:395
local _ok, _res = pcall(function() _v649 = 0
-- stdlib.ml:395
return _v649
end)
if _ok then
exn_648 = _res
else
exn_648 = _res
-- stdlib.ml:395
_v650 = caml_ml_close_channel(oc_644)
-- stdlib.ml:395
end
end
_m217 = function(len_622, ofs_623, s_624, oc_625, _v626) -- stdlib.ml:378
_v628 = invalid_arg_349(_v627)
return _v628
end
_m222 = function(len_604, ofs_605, s_606, oc_607, _v608) -- stdlib.ml:373
_v610 = invalid_arg_349(_v609)
return _v610
end
_m235 = function(param_572, l_573, a_574, _v575) -- stdlib.ml:355
_v576 = iter_560(l_573)
return _v576
end
_m256 = function(i_467, match_468, _v469) -- stdlib.ml:283
return s_457
end
_m257 = function(i_470, match_471, _v472) -- stdlib.ml:282
_v473 = 2
_v474 = int_add(i_470, _v473)
_v475 = loop_459(_v474)
return _v475
end
_m282 = function(n_416, n_417) -- stdlib.ml:224
_v419 = invalid_arg_349(_v418)
return _v419
end
_m302 = function(greet_1018, x_1019, match_1020) _v1021 = {0, greet_1018}
_v1022 = 0
_v1023 = 0
_v1024 = _v1000[104]
-- std_exit.ml:18
_v1025 = _v1024(_v1023)
-- std_exit.ml:18
_v1026 = {0}
_v1027 = 0
return
end
-- stdlib.ml:29
_v348 = {0, Failure_347, s_346}
error(_v348)
end
invalid_arg_349 = function(s_350) -- stdlib.ml:30
local _m119
local _m192
local _m197
local _m207
local _m217
local _m222
local _m235
local _m256
local _m257
local _m282
local _m302
_m119 = function(param_893, _v894) -- stdlib.ml:567
_v895 = 0
_v896 = old_exit_884(_v895)
return _v896
end
_m192 = function(len_709, ofs_710, s_711, ic_712, _v713) -- stdlib.ml:435
_v715 = invalid_arg_349(_v714)
return _v715
end
_m197 = function(len_679, ofs_680, s_681, ic_682, _v683) -- stdlib.ml:422
_v685 = invalid_arg_349(_v684)
return _v685
end
_m207 = function(oc_644, _v645) -- stdlib.ml:395
local _ok, _res = pcall(function() _v649 = 0
-- stdlib.ml:395
return _v649
end)
if _ok then
exn_648 = _res
else
exn_648 = _res
-- stdlib.ml:395
_v650 = caml_ml_close_channel(oc_644)
-- stdlib.ml:395
end
end
_m217 = function(len_622, ofs_623, s_624, oc_625, _v626) -- stdlib.ml:378
_v628 = invalid_arg_349(_v627)
return _v628
end
_m222 = function(len_604, ofs_605, s_606, oc_607, _v608) -- stdlib.ml:373
_v610 = invalid_arg_349(_v609)
return _v610
end
_m235 = function(param_572, l_573, a_574, _v575) -- stdlib.ml:355
_v576 = iter_560(l_573)
return _v576
end
_m256 = function(i_467, match_468, _v469) -- stdlib.ml:283
return s_457
end
_m257 = function(i_470, match_471, _v472) -- stdlib.ml:282
_v473 = 2
_v474 = int_add(i_470, _v473)
_v475 = loop_459(_v474)
return _v475
end
_m282 = function(n_416, n_417) -- stdlib.ml:224
_v419 = invalid_arg_349(_v418)
return _v419
end
_m302 = function(greet_1018, x_1019, match_1020) _v1021 = {0, greet_1018}
_v1022 = 0
_v1023 = 0
_v1024 = _v1000[104]
-- std_exit.ml:18
_v1025 = _v1024(_v1023)
-- std_exit.ml:18
_v1026 = {0}
_v1027 = 0
return
end
-- stdlib.ml:30
_v351 = {0, Invalid_argument_341, s_350}
error(_v351)
end
_v352 = 0
_v353 = caml_fresh_oo_id(_v352)
Exit_355 = {248, _v354, _v353}
min_366 = function(x_368, y_367) -- stdlib.ml:74
local _m119
local _m192
local _m197
local _m207
local _m217
local _m222
local _m235
local _m256
local _m257
local _m282
local _m302
_m119 = function(param_893, _v894) -- stdlib.ml:567
_v895 = 0
_v896 = old_exit_884(_v895)
return _v896
end
_m192 = function(len_709, ofs_710, s_711, ic_712, _v713) -- stdlib.ml:435
_v715 = invalid_arg_349(_v714)
return _v715
end
_m197 = function(len_679, ofs_680, s_681, ic_682, _v683) -- stdlib.ml:422
_v685 = invalid_arg_349(_v684)
return _v685
end
_m207 = function(oc_644, _v645) -- stdlib.ml:395
local _ok, _res = pcall(function() _v649 = 0
-- stdlib.ml:395
return _v649
end)
if _ok then
exn_648 = _res
else
exn_648 = _res
-- stdlib.ml:395
_v650 = caml_ml_close_channel(oc_644)
-- stdlib.ml:395
end
end
_m217 = function(len_622, ofs_623, s_624, oc_625, _v626) -- stdlib.ml:378
_v628 = invalid_arg_349(_v627)
return _v628
end
_m222 = function(len_604, ofs_605, s_606, oc_607, _v608) -- stdlib.ml:373
_v610 = invalid_arg_349(_v609)
return _v610
end
_m235 = function(param_572, l_573, a_574, _v575) -- stdlib.ml:355
_v576 = iter_560(l_573)
return _v576
end
_m256 = function(i_467, match_468, _v469) -- stdlib.ml:283
return s_457
end
_m257 = function(i_470, match_471, _v472) -- stdlib.ml:282
_v473 = 2
_v474 = int_add(i_470, _v473)
_v475 = loop_459(_v474)
return _v475
end
_m282 = function(n_416, n_417) -- stdlib.ml:224
_v419 = invalid_arg_349(_v418)
return _v419
end
_m302 = function(greet_1018, x_1019, match_1020) _v1021 = {0, greet_1018}
_v1022 = 0
_v1023 = 0
_v1024 = _v1000[104]
-- std_exit.ml:18
_v1025 = _v1024(_v1023)
-- std_exit.ml:18
_v1026 = {0}
_v1027 = 0
return
end
-- stdlib.ml:74
_v369 = caml_lessequal(x_368, y_367)
-- stdlib.ml:74
if _v369 then
-- stdlib.ml:74
return x_368
else
-- stdlib.ml:74
return y_367
end
end
max_370 = function(x_372, y_371) -- stdlib.ml:75
local _m119
local _m192
local _m197
local _m207
local _m217
local _m222
local _m235
local _m256
local _m257
local _m282
local _m302
_m119 = function(param_893, _v894) -- stdlib.ml:567
_v895 = 0
_v896 = old_exit_884(_v895)
return _v896
end
_m192 = function(len_709, ofs_710, s_711, ic_712, _v713) -- stdlib.ml:435
_v715 = invalid_arg_349(_v714)
return _v715
end
_m197 = function(len_679, ofs_680, s_681, ic_682, _v683) -- stdlib.ml:422
_v685 = invalid_arg_349(_v684)
return _v685
end
_m207 = function(oc_644, _v645) -- stdlib.ml:395
local _ok, _res = pcall(function() _v649 = 0
-- stdlib.ml:395
return _v649
end)
if _ok then
exn_648 = _res
else
exn_648 = _res
-- stdlib.ml:395
_v650 = caml_ml_close_channel(oc_644)
-- stdlib.ml:395
end
end
_m217 = function(len_622, ofs_623, s_624, oc_625, _v626) -- stdlib.ml:378
_v628 = invalid_arg_349(_v627)
return _v628
end
_m222 = function(len_604, ofs_605, s_606, oc_607, _v608) -- stdlib.ml:373
_v610 = invalid_arg_349(_v609)
return _v610
end
_m235 = function(param_572, l_573, a_574, _v575) -- stdlib.ml:355
_v576 = iter_560(l_573)
return _v576
end
_m256 = function(i_467, match_468, _v469) -- stdlib.ml:283
return s_457
end
_m257 = function(i_470, match_471, _v472) -- stdlib.ml:282
_v473 = 2
_v474 = int_add(i_470, _v473)
_v475 = loop_459(_v474)
return _v475
end
_m282 = function(n_416, n_417) -- stdlib.ml:224
_v419 = invalid_arg_349(_v418)
return _v419
end
_m302 = function(greet_1018, x_1019, match_1020) _v1021 = {0, greet_1018}
_v1022 = 0
_v1023 = 0
_v1024 = _v1000[104]
-- std_exit.ml:18
_v1025 = _v1024(_v1023)
-- std_exit.ml:18
_v1026 = {0}
_v1027 = 0
return
end
-- stdlib.ml:75
_v373 = caml_greaterequal(x_372, y_371)
-- stdlib.ml:75
if _v373 then
-- stdlib.ml:75
return x_372
else
-- stdlib.ml:75
return y_371
end
end
abs_374 = function(x_375) -- stdlib.ml:98
local _m119
local _m192
local _m197
local _m207
local _m217
local _m222
local _m235
local _m256
local _m257
local _m282
local _m302
_m119 = function(param_893, _v894) -- stdlib.ml:567
_v895 = 0
_v896 = old_exit_884(_v895)
return _v896
end
_m192 = function(len_709, ofs_710, s_711, ic_712, _v713) -- stdlib.ml:435
_v715 = invalid_arg_349(_v714)
return _v715
end
_m197 = function(len_679, ofs_680, s_681, ic_682, _v683) -- stdlib.ml:422
_v685 = invalid_arg_349(_v684)
return _v685
end
_m207 = function(oc_644, _v645) -- stdlib.ml:395
local _ok, _res = pcall(function() _v649 = 0
-- stdlib.ml:395
return _v649
end)
if _ok then
exn_648 = _res
else
exn_648 = _res
-- stdlib.ml:395
_v650 = caml_ml_close_channel(oc_644)
-- stdlib.ml:395
end
end
_m217 = function(len_622, ofs_623, s_624, oc_625, _v626) -- stdlib.ml:378
_v628 = invalid_arg_349(_v627)
return _v628
end
_m222 = function(len_604, ofs_605, s_606, oc_607, _v608) -- stdlib.ml:373
_v610 = invalid_arg_349(_v609)
return _v610
end
_m235 = function(param_572, l_573, a_574, _v575) -- stdlib.ml:355
_v576 = iter_560(l_573)
return _v576
end
_m256 = function(i_467, match_468, _v469) -- stdlib.ml:283
return s_457
end
_m257 = function(i_470, match_471, _v472) -- stdlib.ml:282
_v473 = 2
_v474 = int_add(i_470, _v473)
_v475 = loop_459(_v474)
return _v475
end
_m282 = function(n_416, n_417) -- stdlib.ml:224
_v419 = invalid_arg_349(_v418)
return _v419
end
_m302 = function(greet_1018, x_1019, match_1020) _v1021 = {0, greet_1018}
_v1022 = 0
_v1023 = 0
_v1024 = _v1000[104]
-- std_exit.ml:18
_v1025 = _v1024(_v1023)
-- std_exit.ml:18
_v1026 = {0}
_v1027 = 0
return
end
-- stdlib.ml:98
_v376 = 0 <= x_375
if _v376 then
-- stdlib.ml:98
return x_375
else
-- stdlib.ml:98
_v377 = int_neg(x_375)
return _v377
end
end
lnot_378 = function(x_379) -- stdlib.ml:104
local _m119
local _m192
local _m197
local _m207
local _m217
local _m222
local _m235
local _m256
local _m257
local _m282
local _m302
_m119 = function(param_893, _v894) -- stdlib.ml:567
_v895 = 0
_v896 = old_exit_884(_v895)
return _v896
end
_m192 = function(len_709, ofs_710, s_711, ic_712, _v713) -- stdlib.ml:435
_v715 = invalid_arg_349(_v714)
return _v715
end
_m197 = function(len_679, ofs_680, s_681, ic_682, _v683) -- stdlib.ml:422
_v685 = invalid_arg_349(_v684)
return _v685
end
_m207 = function(oc_644, _v645) -- stdlib.ml:395
local _ok, _res = pcall(function() _v649 = 0
-- stdlib.ml:395
return _v649
end)
if _ok then
exn_648 = _res
else
exn_648 = _res
-- stdlib.ml:395
_v650 = caml_ml_close_channel(oc_644)
-- stdlib.ml:395
end
end
_m217 = function(len_622, ofs_623, s_624, oc_625, _v626) -- stdlib.ml:378
_v628 = invalid_arg_349(_v627)
return _v628
end
_m222 = function(len_604, ofs_605, s_606, oc_607, _v608) -- stdlib.ml:373
_v610 = invalid_arg_349(_v609)
return _v610
end
_m235 = function(param_572, l_573, a_574, _v575) -- stdlib.ml:355
_v576 = iter_560(l_573)
return _v576
end
_m256 = function(i_467, match_468, _v469) -- stdlib.ml:283
return s_457
end
_m257 = function(i_470, match_471, _v472) -- stdlib.ml:282
_v473 = 2
_v474 = int_add(i_470, _v473)
_v475 = loop_459(_v474)
return _v475
end
_m282 = function(n_416, n_417) -- stdlib.ml:224
_v419 = invalid_arg_349(_v418)
return _v419
end
_m302 = function(greet_1018, x_1019, match_1020) _v1021 = {0, greet_1018}
_v1022 = 0
_v1023 = 0
_v1024 = _v1000[104]
-- std_exit.ml:18
_v1025 = _v1024(_v1023)
-- std_exit.ml:18
_v1026 = {0}
_v1027 = 0
return
end
-- stdlib.ml:104
_v380 = -2
_v381 = int_xor(x_379, _v380)
return _v381
end
_v382 = 2
_v383 = -2
max_int_384 = int_lsr(_v383, _v382)
_v385 = 2
min_int_386 = int_add(max_int_384, _v385)
-- stdlib.ml:180
infinity_388 = caml_int64_float_of_bits(_v387)
-- stdlib.ml:182
neg_infinity_390 = caml_int64_float_of_bits(_v389)
-- stdlib.ml:184
nan_392 = caml_int64_float_of_bits(_v391)
-- stdlib.ml:186
max_float_394 = caml_int64_float_of_bits(_v393)
-- stdlib.ml:188
min_float_396 = caml_int64_float_of_bits(_v395)
-- stdlib.ml:190
epsilon_float_398 = caml_int64_float_of_bits(_v397)
-- stdlib.ml:190
symbol_concat_399 = function(s1_401, s2_400) -- stdlib.ml:217
local _m119
local _m192
local _m197
local _m207
local _m217
local _m222
local _m235
local _m256
local _m257
local _m282
local _m302
_m119 = function(param_893, _v894) -- stdlib.ml:567
_v895 = 0
_v896 = old_exit_884(_v895)
return _v896
end
_m192 = function(len_709, ofs_710, s_711, ic_712, _v713) -- stdlib.ml:435
_v715 = invalid_arg_349(_v714)
return _v715
end
_m197 = function(len_679, ofs_680, s_681, ic_682, _v683) -- stdlib.ml:422
_v685 = invalid_arg_349(_v684)
return _v685
end
_m207 = function(oc_644, _v645) -- stdlib.ml:395
local _ok, _res = pcall(function() _v649 = 0
-- stdlib.ml:395
return _v649
end)
if _ok then
exn_648 = _res
else
exn_648 = _res
-- stdlib.ml:395
_v650 = caml_ml_close_channel(oc_644)
-- stdlib.ml:395
end
end
_m217 = function(len_622, ofs_623, s_624, oc_625, _v626) -- stdlib.ml:378
_v628 = invalid_arg_349(_v627)
return _v628
end
_m222 = function(len_604, ofs_605, s_606, oc_607, _v608) -- stdlib.ml:373
_v610 = invalid_arg_349(_v609)
return _v610
end
_m235 = function(param_572, l_573, a_574, _v575) -- stdlib.ml:355
_v576 = iter_560(l_573)
return _v576
end
_m256 = function(i_467, match_468, _v469) -- stdlib.ml:283
return s_457
end
_m257 = function(i_470, match_471, _v472) -- stdlib.ml:282
_v473 = 2
_v474 = int_add(i_470, _v473)
_v475 = loop_459(_v474)
return _v475
end
_m282 = function(n_416, n_417) -- stdlib.ml:224
_v419 = invalid_arg_349(_v418)
return _v419
end
_m302 = function(greet_1018, x_1019, match_1020) _v1021 = {0, greet_1018}
_v1022 = 0
_v1023 = 0
_v1024 = _v1000[104]
-- std_exit.ml:18
_v1025 = _v1024(_v1023)
-- std_exit.ml:18
_v1026 = {0}
_v1027 = 0
return
end
-- stdlib.ml:213
l1_402 = caml_ml_string_length(s1_401)
l2_403 = caml_ml_string_length(s2_400)
-- stdlib.ml:214
_v404 = int_add(l1_402, l2_403)
-- stdlib.ml:214
s_405 = caml_create_bytes(_v404)
-- stdlib.ml:215
_v406 = 0
_v407 = 0
-- stdlib.ml:215
_v408 = caml_blit_string(s1_401, _v407, s_405, _v406, l1_402)
-- stdlib.ml:215
_v409 = 0
-- stdlib.ml:216
_v410 = caml_blit_string(s2_400, _v409, s_405, l1_402, l2_403)
-- stdlib.ml:216
_v411 = caml_string_of_bytes(s_405)
return _v411
end
char_of_int_412 = function(n_413) -- stdlib.ml:224
local _m119
local _m192
local _m197
local _m207
local _m217
local _m222
local _m235
local _m256
local _m257
local _m282
local _m302
_m119 = function(param_893, _v894) -- stdlib.ml:567
_v895 = 0
_v896 = old_exit_884(_v895)
return _v896
end
_m192 = function(len_709, ofs_710, s_711, ic_712, _v713) -- stdlib.ml:435
_v715 = invalid_arg_349(_v714)
return _v715
end
_m197 = function(len_679, ofs_680, s_681, ic_682, _v683) -- stdlib.ml:422
_v685 = invalid_arg_349(_v684)
return _v685
end
_m207 = function(oc_644, _v645) -- stdlib.ml:395
local _ok, _res = pcall(function() _v649 = 0
-- stdlib.ml:395
return _v649
end)
if _ok then
exn_648 = _res
else
exn_648 = _res
-- stdlib.ml:395
_v650 = caml_ml_close_channel(oc_644)
-- stdlib.ml:395
end
end
_m217 = function(len_622, ofs_623, s_624, oc_625, _v626) -- stdlib.ml:378
_v628 = invalid_arg_349(_v627)
return _v628
end
_m222 = function(len_604, ofs_605, s_606, oc_607, _v608) -- stdlib.ml:373
_v610 = invalid_arg_349(_v609)
return _v610
end
_m235 = function(param_572, l_573, a_574, _v575) -- stdlib.ml:355
_v576 = iter_560(l_573)
return _v576
end
_m256 = function(i_467, match_468, _v469) -- stdlib.ml:283
return s_457
end
_m257 = function(i_470, match_471, _v472) -- stdlib.ml:282
_v473 = 2
_v474 = int_add(i_470, _v473)
_v475 = loop_459(_v474)
return _v475
end
_m282 = function(n_416, n_417) -- stdlib.ml:224
_v419 = invalid_arg_349(_v418)
return _v419
end
_m302 = function(greet_1018, x_1019, match_1020) _v1021 = {0, greet_1018}
_v1022 = 0
_v1023 = 0
_v1024 = _v1000[104]
-- std_exit.ml:18
_v1025 = _v1024(_v1023)
-- std_exit.ml:18
_v1026 = {0}
_v1027 = 0
return
end
-- stdlib.ml:224
_v414 = 0 <= n_413
if _v414 then
_v415 = 510 < n_413
if _v415 then
return _m282(n_413, n_413)
else
-- stdlib.ml:224
return n_413
end
else
return _m282(n_413, n_413)
end
end
string_of_bool_420 = function(b_421) -- stdlib.ml:254
local _m119
local _m192
local _m197
local _m207
local _m217
local _m222
local _m235
local _m256
local _m257
local _m282
local _m302
_m119 = function(param_893, _v894) -- stdlib.ml:567
_v895 = 0
_v896 = old_exit_884(_v895)
return _v896
end
_m192 = function(len_709, ofs_710, s_711, ic_712, _v713) -- stdlib.ml:435
_v715 = invalid_arg_349(_v714)
return _v715
end
_m197 = function(len_679, ofs_680, s_681, ic_682, _v683) -- stdlib.ml:422
_v685 = invalid_arg_349(_v684)
return _v685
end
_m207 = function(oc_644, _v645) -- stdlib.ml:395
local _ok, _res = pcall(function() _v649 = 0
-- stdlib.ml:395
return _v649
end)
if _ok then
exn_648 = _res
else
exn_648 = _res
-- stdlib.ml:395
_v650 = caml_ml_close_channel(oc_644)
-- stdlib.ml:395
end
end
_m217 = function(len_622, ofs_623, s_624, oc_625, _v626) -- stdlib.ml:378
_v628 = invalid_arg_349(_v627)
return _v628
end
_m222 = function(len_604, ofs_605, s_606, oc_607, _v608) -- stdlib.ml:373
_v610 = invalid_arg_349(_v609)
return _v610
end
_m235 = function(param_572, l_573, a_574, _v575) -- stdlib.ml:355
_v576 = iter_560(l_573)
return _v576
end
_m256 = function(i_467, match_468, _v469) -- stdlib.ml:283
return s_457
end
_m257 = function(i_470, match_471, _v472) -- stdlib.ml:282
_v473 = 2
_v474 = int_add(i_470, _v473)
_v475 = loop_459(_v474)
return _v475
end
_m282 = function(n_416, n_417) -- stdlib.ml:224
_v419 = invalid_arg_349(_v418)
return _v419
end
_m302 = function(greet_1018, x_1019, match_1020) _v1021 = {0, greet_1018}
_v1022 = 0
_v1023 = 0
_v1024 = _v1000[104]
-- std_exit.ml:18
_v1025 = _v1024(_v1023)
-- std_exit.ml:18
_v1026 = {0}
_v1027 = 0
return
end
-- stdlib.ml:254
if b_421 then
-- stdlib.ml:254
return _v422
else
-- stdlib.ml:254
return _v423
end
end
bool_of_string_424 = function(param_425) -- stdlib.ml:258
local _m119
local _m192
local _m197
local _m207
local _m217
local _m222
local _m235
local _m256
local _m257
local _m282
local _m302
_m119 = function(param_893, _v894) -- stdlib.ml:567
_v895 = 0
_v896 = old_exit_884(_v895)
return _v896
end
_m192 = function(len_709, ofs_710, s_711, ic_712, _v713) -- stdlib.ml:435
_v715 = invalid_arg_349(_v714)
return _v715
end
_m197 = function(len_679, ofs_680, s_681, ic_682, _v683) -- stdlib.ml:422
_v685 = invalid_arg_349(_v684)
return _v685
end
_m207 = function(oc_644, _v645) -- stdlib.ml:395
local _ok, _res = pcall(function() _v649 = 0
-- stdlib.ml:395
return _v649
end)
if _ok then
exn_648 = _res
else
exn_648 = _res
-- stdlib.ml:395
_v650 = caml_ml_close_channel(oc_644)
-- stdlib.ml:395
end
end
_m217 = function(len_622, ofs_623, s_624, oc_625, _v626) -- stdlib.ml:378
_v628 = invalid_arg_349(_v627)
return _v628
end
_m222 = function(len_604, ofs_605, s_606, oc_607, _v608) -- stdlib.ml:373
_v610 = invalid_arg_349(_v609)
return _v610
end
_m235 = function(param_572, l_573, a_574, _v575) -- stdlib.ml:355
_v576 = iter_560(l_573)
return _v576
end
_m256 = function(i_467, match_468, _v469) -- stdlib.ml:283
return s_457
end
_m257 = function(i_470, match_471, _v472) -- stdlib.ml:282
_v473 = 2
_v474 = int_add(i_470, _v473)
_v475 = loop_459(_v474)
return _v475
end
_m282 = function(n_416, n_417) -- stdlib.ml:224
_v419 = invalid_arg_349(_v418)
return _v419
end
_m302 = function(greet_1018, x_1019, match_1020) _v1021 = {0, greet_1018}
_v1022 = 0
_v1023 = 0
_v1024 = _v1000[104]
-- std_exit.ml:18
_v1025 = _v1024(_v1023)
-- std_exit.ml:18
_v1026 = {0}
_v1027 = 0
return
end
-- stdlib.ml:255
_v427 = caml_string_notequal(param_425, _v426)
if _v427 then
_v429 = caml_string_notequal(param_425, _v428)
if _v429 then
-- stdlib.ml:258
_v431 = invalid_arg_349(_v430)
return _v431
else
-- stdlib.ml:256
_v432 = 2
return _v432
end
else
-- stdlib.ml:257
_v433 = 0
return _v433
end
end
bool_of_string_opt_434 = function(param_435) -- stdlib.ml:263
local _m119
local _m192
local _m197
local _m207
local _m217
local _m222
local _m235
local _m256
local _m257
local _m282
local _m302
_m119 = function(param_893, _v894) -- stdlib.ml:567
_v895 = 0
_v896 = old_exit_884(_v895)
return _v896
end
_m192 = function(len_709, ofs_710, s_711, ic_712, _v713) -- stdlib.ml:435
_v715 = invalid_arg_349(_v714)
return _v715
end
_m197 = function(len_679, ofs_680, s_681, ic_682, _v683) -- stdlib.ml:422
_v685 = invalid_arg_349(_v684)
return _v685
end
_m207 = function(oc_644, _v645) -- stdlib.ml:395
local _ok, _res = pcall(function() _v649 = 0
-- stdlib.ml:395
return _v649
end)
if _ok then
exn_648 = _res
else
exn_648 = _res
-- stdlib.ml:395
_v650 = caml_ml_close_channel(oc_644)
-- stdlib.ml:395
end
end
_m217 = function(len_622, ofs_623, s_624, oc_625, _v626) -- stdlib.ml:378
_v628 = invalid_arg_349(_v627)
return _v628
end
_m222 = function(len_604, ofs_605, s_606, oc_607, _v608) -- stdlib.ml:373
_v610 = invalid_arg_349(_v609)
return _v610
end
_m235 = function(param_572, l_573, a_574, _v575) -- stdlib.ml:355
_v576 = iter_560(l_573)
return _v576
end
_m256 = function(i_467, match_468, _v469) -- stdlib.ml:283
return s_457
end
_m257 = function(i_470, match_471, _v472) -- stdlib.ml:282
_v473 = 2
_v474 = int_add(i_470, _v473)
_v475 = loop_459(_v474)
return _v475
end
_m282 = function(n_416, n_417) -- stdlib.ml:224
_v419 = invalid_arg_349(_v418)
return _v419
end
_m302 = function(greet_1018, x_1019, match_1020) _v1021 = {0, greet_1018}
_v1022 = 0
_v1023 = 0
_v1024 = _v1000[104]
-- std_exit.ml:18
_v1025 = _v1024(_v1023)
-- std_exit.ml:18
_v1026 = {0}
_v1027 = 0
return
end
-- stdlib.ml:260
_v437 = caml_string_notequal(param_435, _v436)
if _v437 then
_v439 = caml_string_notequal(param_435, _v438)
if _v439 then
-- stdlib.ml:263
_v440 = 0
return _v440
else
-- stdlib.ml:261
return _v441
end
else
-- stdlib.ml:262
return _v442
end
end
string_of_int_443 = function(n_444) -- stdlib.ml:266
local _m119
local _m192
local _m197
local _m207
local _m217
local _m222
local _m235
local _m256
local _m257
local _m282
local _m302
_m119 = function(param_893, _v894) -- stdlib.ml:567
_v895 = 0
_v896 = old_exit_884(_v895)
return _v896
end
_m192 = function(len_709, ofs_710, s_711, ic_712, _v713) -- stdlib.ml:435
_v715 = invalid_arg_349(_v714)
return _v715
end
_m197 = function(len_679, ofs_680, s_681, ic_682, _v683) -- stdlib.ml:422
_v685 = invalid_arg_349(_v684)
return _v685
end
_m207 = function(oc_644, _v645) -- stdlib.ml:395
local _ok, _res = pcall(function() _v649 = 0
-- stdlib.ml:395
return _v649
end)
if _ok then
exn_648 = _res
else
exn_648 = _res
-- stdlib.ml:395
_v650 = caml_ml_close_channel(oc_644)
-- stdlib.ml:395
end
end
_m217 = function(len_622, ofs_623, s_624, oc_625, _v626) -- stdlib.ml:378
_v628 = invalid_arg_349(_v627)
return _v628
end
_m222 = function(len_604, ofs_605, s_606, oc_607, _v608) -- stdlib.ml:373
_v610 = invalid_arg_349(_v609)
return _v610
end
_m235 = function(param_572, l_573, a_574, _v575) -- stdlib.ml:355
_v576 = iter_560(l_573)
return _v576
end
_m256 = function(i_467, match_468, _v469) -- stdlib.ml:283
return s_457
end
_m257 = function(i_470, match_471, _v472) -- stdlib.ml:282
_v473 = 2
_v474 = int_add(i_470, _v473)
_v475 = loop_459(_v474)
return _v475
end
_m282 = function(n_416, n_417) -- stdlib.ml:224
_v419 = invalid_arg_349(_v418)
return _v419
end
_m302 = function(greet_1018, x_1019, match_1020) _v1021 = {0, greet_1018}
_v1022 = 0
_v1023 = 0
_v1024 = _v1000[104]
-- std_exit.ml:18
_v1025 = _v1024(_v1023)
-- std_exit.ml:18
_v1026 = {0}
_v1027 = 0
return
end
-- stdlib.ml:266
_v446 = caml_format_int(_v445, n_444)
-- stdlib.ml:266
return _v446
end
int_of_string_opt_447 = function(s_448) -- stdlib.ml:273
local _m119
local _m192
local _m197
local _m207
local _m217
local _m222
local _m235
local _m256
local _m257
local _m282
local _m302
_m119 = function(param_893, _v894) -- stdlib.ml:567
_v895 = 0
_v896 = old_exit_884(_v895)
return _v896
end
_m192 = function(len_709, ofs_710, s_711, ic_712, _v713) -- stdlib.ml:435
_v715 = invalid_arg_349(_v714)
return _v715
end
_m197 = function(len_679, ofs_680, s_681, ic_682, _v683) -- stdlib.ml:422
_v685 = invalid_arg_349(_v684)
return _v685
end
_m207 = function(oc_644, _v645) -- stdlib.ml:395
local _ok, _res = pcall(function() _v649 = 0
-- stdlib.ml:395
return _v649
end)
if _ok then
exn_648 = _res
else
exn_648 = _res
-- stdlib.ml:395
_v650 = caml_ml_close_channel(oc_644)
-- stdlib.ml:395
end
end
_m217 = function(len_622, ofs_623, s_624, oc_625, _v626) -- stdlib.ml:378
_v628 = invalid_arg_349(_v627)
return _v628
end
_m222 = function(len_604, ofs_605, s_606, oc_607, _v608) -- stdlib.ml:373
_v610 = invalid_arg_349(_v609)
return _v610
end
_m235 = function(param_572, l_573, a_574, _v575) -- stdlib.ml:355
_v576 = iter_560(l_573)
return _v576
end
_m256 = function(i_467, match_468, _v469) -- stdlib.ml:283
return s_457
end
_m257 = function(i_470, match_471, _v472) -- stdlib.ml:282
_v473 = 2
_v474 = int_add(i_470, _v473)
_v475 = loop_459(_v474)
return _v475
end
_m282 = function(n_416, n_417) -- stdlib.ml:224
_v419 = invalid_arg_349(_v418)
return _v419
end
_m302 = function(greet_1018, x_1019, match_1020) _v1021 = {0, greet_1018}
_v1022 = 0
_v1023 = 0
_v1024 = _v1000[104]
-- std_exit.ml:18
_v1025 = _v1024(_v1023)
-- std_exit.ml:18
_v1026 = {0}
_v1027 = 0
return
end
-- stdlib.ml:272
local _ok, _res = pcall(function() tag_451 = exn_450[2]
_v452 = tag_451 == Failure_347
if _v452 then
-- stdlib.ml:273
_v453 = 0
return _v453
else
error(exn_450)
end
end)
if _ok then
exn_450 = _res
else
exn_450 = _res
-- stdlib.ml:272
_v454 = caml_int_of_string(s_448)
-- stdlib.ml:272
_v455 = {0, _v454}
end
end
valid_float_lexem_456 = function(s_457) -- stdlib.ml:285
local _m119
local _m192
local _m197
local _m207
local _m217
local _m222
local _m235
local _m256
local _m257
local _m282
local _m302
_m119 = function(param_893, _v894) -- stdlib.ml:567
_v895 = 0
_v896 = old_exit_884(_v895)
return _v896
end
_m192 = function(len_709, ofs_710, s_711, ic_712, _v713) -- stdlib.ml:435
_v715 = invalid_arg_349(_v714)
return _v715
end
_m197 = function(len_679, ofs_680, s_681, ic_682, _v683) -- stdlib.ml:422
_v685 = invalid_arg_349(_v684)
return _v685
end
_m207 = function(oc_644, _v645) -- stdlib.ml:395
local _ok, _res = pcall(function() _v649 = 0
-- stdlib.ml:395
return _v649
end)
if _ok then
exn_648 = _res
else
exn_648 = _res
-- stdlib.ml:395
_v650 = caml_ml_close_channel(oc_644)
-- stdlib.ml:395
end
end
_m217 = function(len_622, ofs_623, s_624, oc_625, _v626) -- stdlib.ml:378
_v628 = invalid_arg_349(_v627)
return _v628
end
_m222 = function(len_604, ofs_605, s_606, oc_607, _v608) -- stdlib.ml:373
_v610 = invalid_arg_349(_v609)
return _v610
end
_m235 = function(param_572, l_573, a_574, _v575) -- stdlib.ml:355
_v576 = iter_560(l_573)
return _v576
end
_m256 = function(i_467, match_468, _v469) -- stdlib.ml:283
return s_457
end
_m257 = function(i_470, match_471, _v472) -- stdlib.ml:282
_v473 = 2
_v474 = int_add(i_470, _v473)
_v475 = loop_459(_v474)
return _v475
end
_m282 = function(n_416, n_417) -- stdlib.ml:224
_v419 = invalid_arg_349(_v418)
return _v419
end
_m302 = function(greet_1018, x_1019, match_1020) _v1021 = {0, greet_1018}
_v1022 = 0
_v1023 = 0
_v1024 = _v1000[104]
-- std_exit.ml:18
_v1025 = _v1024(_v1023)
-- std_exit.ml:18
_v1026 = {0}
_v1027 = 0
return
end
-- stdlib.ml:278
l_458 = caml_ml_string_length(s_457)
-- stdlib.ml:279
loop_459 = function(i_460) -- stdlib.ml:283
local _m119
local _m192
local _m197
local _m207
local _m217
local _m222
local _m235
local _m256
local _m257
local _m282
local _m302
_m119 = function(param_893, _v894) -- stdlib.ml:567
_v895 = 0
_v896 = old_exit_884(_v895)
return _v896
end
_m192 = function(len_709, ofs_710, s_711, ic_712, _v713) -- stdlib.ml:435
_v715 = invalid_arg_349(_v714)
return _v715
end
_m197 = function(len_679, ofs_680, s_681, ic_682, _v683) -- stdlib.ml:422
_v685 = invalid_arg_349(_v684)
return _v685
end
_m207 = function(oc_644, _v645) -- stdlib.ml:395
local _ok, _res = pcall(function() _v649 = 0
-- stdlib.ml:395
return _v649
end)
if _ok then
exn_648 = _res
else
exn_648 = _res
-- stdlib.ml:395
_v650 = caml_ml_close_channel(oc_644)
-- stdlib.ml:395
end
end
_m217 = function(len_622, ofs_623, s_624, oc_625, _v626) -- stdlib.ml:378
_v628 = invalid_arg_349(_v627)
return _v628
end
_m222 = function(len_604, ofs_605, s_606, oc_607, _v608) -- stdlib.ml:373
_v610 = invalid_arg_349(_v609)
return _v610
end
_m235 = function(param_572, l_573, a_574, _v575) -- stdlib.ml:355
_v576 = iter_560(l_573)
return _v576
end
_m256 = function(i_467, match_468, _v469) -- stdlib.ml:283
return s_457
end
_m257 = function(i_470, match_471, _v472) -- stdlib.ml:282
_v473 = 2
_v474 = int_add(i_470, _v473)
_v475 = loop_459(_v474)
return _v475
end
_m282 = function(n_416, n_417) -- stdlib.ml:224
_v419 = invalid_arg_349(_v418)
return _v419
end
_m302 = function(greet_1018, x_1019, match_1020) _v1021 = {0, greet_1018}
_v1022 = 0
_v1023 = 0
_v1024 = _v1000[104]
-- std_exit.ml:18
_v1025 = _v1024(_v1023)
-- std_exit.ml:18
_v1026 = {0}
_v1027 = 0
return
end
-- stdlib.ml:280
_v461 = l_458 <= i_460
if _v461 then
-- stdlib.ml:280
_v463 = symbol_concat_399(s_457, _v462)
return _v463
else
-- stdlib.ml:281
_v464 = caml_string_get(s_457, i_460)
-- stdlib.ml:281
_v465 = 96 <= _v464
if _v465 then
_v466 = 116 <= _v464
if _v466 then
return _m256(i_460, _v464, _v464)
else
return _m257(i_460, _v464, _v464)
end
else
_v476 = 90 == _v464
if _v476 then
return _m257(i_460, _v464, _v464)
else
return _m256(i_460, _v464, _v464)
end
end
end
end
-- stdlib.ml:285
_v477 = 0
_v478 = loop_459(_v477)
return _v478
end
string_of_float_479 = function(f_480) -- stdlib.ml:287
local _m119
local _m192
local _m197
local _m207
local _m217
local _m222
local _m235
local _m256
local _m257
local _m282
local _m302
_m119 = function(param_893, _v894) -- stdlib.ml:567
_v895 = 0
_v896 = old_exit_884(_v895)
return _v896
end
_m192 = function(len_709, ofs_710, s_711, ic_712, _v713) -- stdlib.ml:435
_v715 = invalid_arg_349(_v714)
return _v715
end
_m197 = function(len_679, ofs_680, s_681, ic_682, _v683) -- stdlib.ml:422
_v685 = invalid_arg_349(_v684)
return _v685
end
_m207 = function(oc_644, _v645) -- stdlib.ml:395
local _ok, _res = pcall(function() _v649 = 0
-- stdlib.ml:395
return _v649
end)
if _ok then
exn_648 = _res
else
exn_648 = _res
-- stdlib.ml:395
_v650 = caml_ml_close_channel(oc_644)
-- stdlib.ml:395
end
end
_m217 = function(len_622, ofs_623, s_624, oc_625, _v626) -- stdlib.ml:378
_v628 = invalid_arg_349(_v627)
return _v628
end
_m222 = function(len_604, ofs_605, s_606, oc_607, _v608) -- stdlib.ml:373
_v610 = invalid_arg_349(_v609)
return _v610
end
_m235 = function(param_572, l_573, a_574, _v575) -- stdlib.ml:355
_v576 = iter_560(l_573)
return _v576
end
_m256 = function(i_467, match_468, _v469) -- stdlib.ml:283
return s_457
end
_m257 = function(i_470, match_471, _v472) -- stdlib.ml:282
_v473 = 2
_v474 = int_add(i_470, _v473)
_v475 = loop_459(_v474)
return _v475
end
_m282 = function(n_416, n_417) -- stdlib.ml:224
_v419 = invalid_arg_349(_v418)
return _v419
end
_m302 = function(greet_1018, x_1019, match_1020) _v1021 = {0, greet_1018}
_v1022 = 0
_v1023 = 0
_v1024 = _v1000[104]
-- std_exit.ml:18
_v1025 = _v1024(_v1023)
-- std_exit.ml:18
_v1026 = {0}
_v1027 = 0
return
end
-- stdlib.ml:287
_v482 = caml_format_float(_v481, f_480)
-- stdlib.ml:287
_v483 = valid_float_lexem_456(_v482)
return _v483
end
float_of_string_opt_484 = function(s_485) -- stdlib.ml:294
local _m119
local _m192
local _m197
local _m207
local _m217
local _m222
local _m235
local _m256
local _m257
local _m282
local _m302
_m119 = function(param_893, _v894) -- stdlib.ml:567
_v895 = 0
_v896 = old_exit_884(_v895)
return _v896
end
_m192 = function(len_709, ofs_710, s_711, ic_712, _v713) -- stdlib.ml:435
_v715 = invalid_arg_349(_v714)
return _v715
end
_m197 = function(len_679, ofs_680, s_681, ic_682, _v683) -- stdlib.ml:422
_v685 = invalid_arg_349(_v684)
return _v685
end
_m207 = function(oc_644, _v645) -- stdlib.ml:395
local _ok, _res = pcall(function() _v649 = 0
-- stdlib.ml:395
return _v649
end)
if _ok then
exn_648 = _res
else
exn_648 = _res
-- stdlib.ml:395
_v650 = caml_ml_close_channel(oc_644)
-- stdlib.ml:395
end
end
_m217 = function(len_622, ofs_623, s_624, oc_625, _v626) -- stdlib.ml:378
_v628 = invalid_arg_349(_v627)
return _v628
end
_m222 = function(len_604, ofs_605, s_606, oc_607, _v608) -- stdlib.ml:373
_v610 = invalid_arg_349(_v609)
return _v610
end
_m235 = function(param_572, l_573, a_574, _v575) -- stdlib.ml:355
_v576 = iter_560(l_573)
return _v576
end
_m256 = function(i_467, match_468, _v469) -- stdlib.ml:283
return s_457
end
_m257 = function(i_470, match_471, _v472) -- stdlib.ml:282
_v473 = 2
_v474 = int_add(i_470, _v473)
_v475 = loop_459(_v474)
return _v475
end
_m282 = function(n_416, n_417) -- stdlib.ml:224
_v419 = invalid_arg_349(_v418)
return _v419
end
_m302 = function(greet_1018, x_1019, match_1020) _v1021 = {0, greet_1018}
_v1022 = 0
_v1023 = 0
_v1024 = _v1000[104]
-- std_exit.ml:18
_v1025 = _v1024(_v1023)
-- std_exit.ml:18
_v1026 = {0}
_v1027 = 0
return
end
-- stdlib.ml:293
local _ok, _res = pcall(function() tag_488 = exn_487[2]
_v489 = tag_488 == Failure_347
if _v489 then
-- stdlib.ml:294
_v490 = 0
return _v490
else
error(exn_487)
end
end)
if _ok then
exn_487 = _res
else
exn_487 = _res
-- stdlib.ml:293
_v491 = caml_float_of_string(s_485)
-- stdlib.ml:293
_v492 = {0, _v491}
end
end
symbol_493 = function(l1_496, l2_495) -- stdlib.ml:303
local _m119
local _m192
local _m197
local _m207
local _m217
local _m222
local _m235
local _m256
local _m257
local _m282
local _m302
_m119 = function(param_893, _v894) -- stdlib.ml:567
_v895 = 0
_v896 = old_exit_884(_v895)
return _v896
end
_m192 = function(len_709, ofs_710, s_711, ic_712, _v713) -- stdlib.ml:435
_v715 = invalid_arg_349(_v714)
return _v715
end
_m197 = function(len_679, ofs_680, s_681, ic_682, _v683) -- stdlib.ml:422
_v685 = invalid_arg_349(_v684)
return _v685
end
_m207 = function(oc_644, _v645) -- stdlib.ml:395
local _ok, _res = pcall(function() _v649 = 0
-- stdlib.ml:395
return _v649
end)
if _ok then
exn_648 = _res
else
exn_648 = _res
-- stdlib.ml:395
_v650 = caml_ml_close_channel(oc_644)
-- stdlib.ml:395
end
end
_m217 = function(len_622, ofs_623, s_624, oc_625, _v626) -- stdlib.ml:378
_v628 = invalid_arg_349(_v627)
return _v628
end
_m222 = function(len_604, ofs_605, s_606, oc_607, _v608) -- stdlib.ml:373
_v610 = invalid_arg_349(_v609)
return _v610
end
_m235 = function(param_572, l_573, a_574, _v575) -- stdlib.ml:355
_v576 = iter_560(l_573)
return _v576
end
_m256 = function(i_467, match_468, _v469) -- stdlib.ml:283
return s_457
end
_m257 = function(i_470, match_471, _v472) -- stdlib.ml:282
_v473 = 2
_v474 = int_add(i_470, _v473)
_v475 = loop_459(_v474)
return _v475
end
_m282 = function(n_416, n_417) -- stdlib.ml:224
_v419 = invalid_arg_349(_v418)
return _v419
end
_m302 = function(greet_1018, x_1019, match_1020) _v1021 = {0, greet_1018}
_v1022 = 0
_v1023 = 0
_v1024 = _v1000[104]
-- std_exit.ml:18
_v1025 = _v1024(_v1023)
-- std_exit.ml:18
_v1026 = {0}
_v1027 = 0
return
end
-- stdlib.ml:299
if l1_496 then
match_497 = l1_496[3]
h1_498 = l1_496[2]
if match_497 then
match_499 = match_497[3]
h2_500 = match_497[2]
if match_499 then
tl_501 = match_499[3]
h3_502 = match_499[2]
_v503 = 48058
-- stdlib.ml:303
block_504 = {0, h3_502, _v503}
_v505 = 2
-- stdlib.ml:303
_v506 = dps_494(block_504, _v505, tl_501, l2_495)
-- stdlib.ml:303
_v507 = {0, h2_500, block_504}
_v508 = {0, h1_498, _v507}
return _v508
else
-- stdlib.ml:302
_v509 = {0, h2_500, l2_495}
_v510 = {0, h1_498, _v509}
return _v510
end
else
-- stdlib.ml:301
_v511 = {0, h1_498, l2_495}
return _v511
end
else
-- stdlib.ml:300
return l2_495
end
end
dps_494 = function(dst_515, offset_514, l1_513, l2_512) -- stdlib.ml:303
local _m119
local _m192
local _m197
local _m207
local _m217
local _m222
local _m235
local _m256
local _m257
local _m282
local _m302
_m119 = function(param_893, _v894) -- stdlib.ml:567
_v895 = 0
_v896 = old_exit_884(_v895)
return _v896
end
_m192 = function(len_709, ofs_710, s_711, ic_712, _v713) -- stdlib.ml:435
_v715 = invalid_arg_349(_v714)
return _v715
end
_m197 = function(len_679, ofs_680, s_681, ic_682, _v683) -- stdlib.ml:422
_v685 = invalid_arg_349(_v684)
return _v685
end
_m207 = function(oc_644, _v645) -- stdlib.ml:395
local _ok, _res = pcall(function() _v649 = 0
-- stdlib.ml:395
return _v649
end)
if _ok then
exn_648 = _res
else
exn_648 = _res
-- stdlib.ml:395
_v650 = caml_ml_close_channel(oc_644)
-- stdlib.ml:395
end
end
_m217 = function(len_622, ofs_623, s_624, oc_625, _v626) -- stdlib.ml:378
_v628 = invalid_arg_349(_v627)
return _v628
end
_m222 = function(len_604, ofs_605, s_606, oc_607, _v608) -- stdlib.ml:373
_v610 = invalid_arg_349(_v609)
return _v610
end
_m235 = function(param_572, l_573, a_574, _v575) -- stdlib.ml:355
_v576 = iter_560(l_573)
return _v576
end
_m256 = function(i_467, match_468, _v469) -- stdlib.ml:283
return s_457
end
_m257 = function(i_470, match_471, _v472) -- stdlib.ml:282
_v473 = 2
_v474 = int_add(i_470, _v473)
_v475 = loop_459(_v474)
return _v475
end
_m282 = function(n_416, n_417) -- stdlib.ml:224
_v419 = invalid_arg_349(_v418)
return _v419
end
_m302 = function(greet_1018, x_1019, match_1020) _v1021 = {0, greet_1018}
_v1022 = 0
_v1023 = 0
_v1024 = _v1000[104]
-- std_exit.ml:18
_v1025 = _v1024(_v1023)
-- std_exit.ml:18
_v1026 = {0}
_v1027 = 0
return
end
-- stdlib.ml:299
if l1_513 then
match_516 = l1_513[3]
h1_517 = l1_513[2]
if match_516 then
match_518 = match_516[3]
h2_519 = match_516[2]
if match_518 then
tl_520 = match_518[3]
h3_521 = match_518[2]
_v522 = 48058
-- stdlib.ml:303
_v523 = {0, h3_521, _v522}
_v524 = {0, h2_519, _v523}
_v525 = {0, h1_517, _v524}
dst_515[offset_514 + 1] = _v525
_v526 = 0
_v527 = 2
_v528 = dps_494(_v523, _v527, tl_520, l2_512)
return _v528
else
-- stdlib.ml:302
_v529 = {0, h2_519, l2_512}
_v530 = {0, h1_517, _v529}
dst_515[offset_514 + 1] = _v530
_v531 = 0
return _v531
end
else
-- stdlib.ml:301
_v532 = {0, h1_517, l2_512}
dst_515[offset_514 + 1] = _v532
_v533 = 0
return _v533
end
else
-- stdlib.ml:300
dst_515[offset_514 + 1] = l2_512
_v534 = 0
return _v534
end
end
_v535 = 0
-- stdlib.ml:314
stdin_536 = caml_ml_open_descriptor_in(_v535)
-- stdlib.ml:314
_v537 = 2
-- stdlib.ml:315
stdout_538 = caml_ml_open_descriptor_out(_v537)
-- stdlib.ml:315
_v539 = 4
-- stdlib.ml:316
stderr_540 = caml_ml_open_descriptor_out(_v539)
-- stdlib.ml:316
open_out_gen_541 = function(mode_544, perm_543, name_542) -- stdlib.ml:333
local _m119
local _m192
local _m197
local _m207
local _m217
local _m222
local _m235
local _m256
local _m257
local _m282
local _m302
_m119 = function(param_893, _v894) -- stdlib.ml:567
_v895 = 0
_v896 = old_exit_884(_v895)
return _v896
end
_m192 = function(len_709, ofs_710, s_711, ic_712, _v713) -- stdlib.ml:435
_v715 = invalid_arg_349(_v714)
return _v715
end
_m197 = function(len_679, ofs_680, s_681, ic_682, _v683) -- stdlib.ml:422
_v685 = invalid_arg_349(_v684)
return _v685
end
_m207 = function(oc_644, _v645) -- stdlib.ml:395
local _ok, _res = pcall(function() _v649 = 0
-- stdlib.ml:395
return _v649
end)
if _ok then
exn_648 = _res
else
exn_648 = _res
-- stdlib.ml:395
_v650 = caml_ml_close_channel(oc_644)
-- stdlib.ml:395
end
end
_m217 = function(len_622, ofs_623, s_624, oc_625, _v626) -- stdlib.ml:378
_v628 = invalid_arg_349(_v627)
return _v628
end
_m222 = function(len_604, ofs_605, s_606, oc_607, _v608) -- stdlib.ml:373
_v610 = invalid_arg_349(_v609)
return _v610
end
_m235 = function(param_572, l_573, a_574, _v575) -- stdlib.ml:355
_v576 = iter_560(l_573)
return _v576
end
_m256 = function(i_467, match_468, _v469) -- stdlib.ml:283
return s_457
end
_m257 = function(i_470, match_471, _v472) -- stdlib.ml:282
_v473 = 2
_v474 = int_add(i_470, _v473)
_v475 = loop_459(_v474)
return _v475
end
_m282 = function(n_416, n_417) -- stdlib.ml:224
_v419 = invalid_arg_349(_v418)
return _v419
end
_m302 = function(greet_1018, x_1019, match_1020) _v1021 = {0, greet_1018}
_v1022 = 0
_v1023 = 0
_v1024 = _v1000[104]
-- std_exit.ml:18
_v1025 = _v1024(_v1023)
-- std_exit.ml:18
_v1026 = {0}
_v1027 = 0
return
end
-- stdlib.ml:331
_v545 = caml_sys_open(name_542, mode_544, perm_543)
-- stdlib.ml:331
c_546 = caml_ml_open_descriptor_out(_v545)
-- stdlib.ml:332
_v547 = caml_ml_set_channel_name(c_546, name_542)
-- stdlib.ml:332
return c_546
end
open_out_548 = function(name_549) -- stdlib.ml:336
local _m119
local _m192
local _m197
local _m207
local _m217
local _m222
local _m235
local _m256
local _m257
local _m282
local _m302
_m119 = function(param_893, _v894) -- stdlib.ml:567
_v895 = 0
_v896 = old_exit_884(_v895)
return _v896
end
_m192 = function(len_709, ofs_710, s_711, ic_712, _v713) -- stdlib.ml:435
_v715 = invalid_arg_349(_v714)
return _v715
end
_m197 = function(len_679, ofs_680, s_681, ic_682, _v683) -- stdlib.ml:422
_v685 = invalid_arg_349(_v684)
return _v685
end
_m207 = function(oc_644, _v645) -- stdlib.ml:395
local _ok, _res = pcall(function() _v649 = 0
-- stdlib.ml:395
return _v649
end)
if _ok then
exn_648 = _res
else
exn_648 = _res
-- stdlib.ml:395
_v650 = caml_ml_close_channel(oc_644)
-- stdlib.ml:395
end
end
_m217 = function(len_622, ofs_623, s_624, oc_625, _v626) -- stdlib.ml:378
_v628 = invalid_arg_349(_v627)
return _v628
end
_m222 = function(len_604, ofs_605, s_606, oc_607, _v608) -- stdlib.ml:373
_v610 = invalid_arg_349(_v609)
return _v610
end
_m235 = function(param_572, l_573, a_574, _v575) -- stdlib.ml:355
_v576 = iter_560(l_573)
return _v576
end
_m256 = function(i_467, match_468, _v469) -- stdlib.ml:283
return s_457
end
_m257 = function(i_470, match_471, _v472) -- stdlib.ml:282
_v473 = 2
_v474 = int_add(i_470, _v473)
_v475 = loop_459(_v474)
return _v475
end
_m282 = function(n_416, n_417) -- stdlib.ml:224
_v419 = invalid_arg_349(_v418)
return _v419
end
_m302 = function(greet_1018, x_1019, match_1020) _v1021 = {0, greet_1018}
_v1022 = 0
_v1023 = 0
_v1024 = _v1000[104]
-- std_exit.ml:18
_v1025 = _v1024(_v1023)
-- std_exit.ml:18
_v1026 = {0}
_v1027 = 0
return
end
-- stdlib.ml:336
_v550 = 876
_v552 = open_out_gen_541(_v551, _v550, name_549)
return _v552
end
open_out_bin_553 = function(name_554) -- stdlib.ml:339
local _m119
local _m192
local _m197
local _m207
local _m217
local _m222
local _m235
local _m256
local _m257
local _m282
local _m302
_m119 = function(param_893, _v894) -- stdlib.ml:567
_v895 = 0
_v896 = old_exit_884(_v895)
return _v896
end
_m192 = function(len_709, ofs_710, s_711, ic_712, _v713) -- stdlib.ml:435
_v715 = invalid_arg_349(_v714)
return _v715
end
_m197 = function(len_679, ofs_680, s_681, ic_682, _v683) -- stdlib.ml:422
_v685 = invalid_arg_349(_v684)
return _v685
end
_m207 = function(oc_644, _v645) -- stdlib.ml:395
local _ok, _res = pcall(function() _v649 = 0
-- stdlib.ml:395
return _v649
end)
if _ok then
exn_648 = _res
else
exn_648 = _res
-- stdlib.ml:395
_v650 = caml_ml_close_channel(oc_644)
-- stdlib.ml:395
end
end
_m217 = function(len_622, ofs_623, s_624, oc_625, _v626) -- stdlib.ml:378
_v628 = invalid_arg_349(_v627)
return _v628
end
_m222 = function(len_604, ofs_605, s_606, oc_607, _v608) -- stdlib.ml:373
_v610 = invalid_arg_349(_v609)
return _v610
end
_m235 = function(param_572, l_573, a_574, _v575) -- stdlib.ml:355
_v576 = iter_560(l_573)
return _v576
end
_m256 = function(i_467, match_468, _v469) -- stdlib.ml:283
return s_457
end
_m257 = function(i_470, match_471, _v472) -- stdlib.ml:282
_v473 = 2
_v474 = int_add(i_470, _v473)
_v475 = loop_459(_v474)
return _v475
end
_m282 = function(n_416, n_417) -- stdlib.ml:224
_v419 = invalid_arg_349(_v418)
return _v419
end
_m302 = function(greet_1018, x_1019, match_1020) _v1021 = {0, greet_1018}
_v1022 = 0
_v1023 = 0
_v1024 = _v1000[104]
-- std_exit.ml:18
_v1025 = _v1024(_v1023)
-- std_exit.ml:18
_v1026 = {0}
_v1027 = 0
return
end
-- stdlib.ml:339
_v555 = 876
_v557 = open_out_gen_541(_v556, _v555, name_554)
return _v557
end
flush_all_558 = function(param_559) -- stdlib.ml:356
local _m119
local _m192
local _m197
local _m207
local _m217
local _m222
local _m235
local _m256
local _m257
local _m282
local _m302
_m119 = function(param_893, _v894) -- stdlib.ml:567
_v895 = 0
_v896 = old_exit_884(_v895)
return _v896
end
_m192 = function(len_709, ofs_710, s_711, ic_712, _v713) -- stdlib.ml:435
_v715 = invalid_arg_349(_v714)
return _v715
end
_m197 = function(len_679, ofs_680, s_681, ic_682, _v683) -- stdlib.ml:422
_v685 = invalid_arg_349(_v684)
return _v685
end
_m207 = function(oc_644, _v645) -- stdlib.ml:395
local _ok, _res = pcall(function() _v649 = 0
-- stdlib.ml:395
return _v649
end)
if _ok then
exn_648 = _res
else
exn_648 = _res
-- stdlib.ml:395
_v650 = caml_ml_close_channel(oc_644)
-- stdlib.ml:395
end
end
_m217 = function(len_622, ofs_623, s_624, oc_625, _v626) -- stdlib.ml:378
_v628 = invalid_arg_349(_v627)
return _v628
end
_m222 = function(len_604, ofs_605, s_606, oc_607, _v608) -- stdlib.ml:373
_v610 = invalid_arg_349(_v609)
return _v610
end
_m235 = function(param_572, l_573, a_574, _v575) -- stdlib.ml:355
_v576 = iter_560(l_573)
return _v576
end
_m256 = function(i_467, match_468, _v469) -- stdlib.ml:283
return s_457
end
_m257 = function(i_470, match_471, _v472) -- stdlib.ml:282
_v473 = 2
_v474 = int_add(i_470, _v473)
_v475 = loop_459(_v474)
return _v475
end
_m282 = function(n_416, n_417) -- stdlib.ml:224
_v419 = invalid_arg_349(_v418)
return _v419
end
_m302 = function(greet_1018, x_1019, match_1020) _v1021 = {0, greet_1018}
_v1022 = 0
_v1023 = 0
_v1024 = _v1000[104]
-- std_exit.ml:18
_v1025 = _v1024(_v1023)
-- std_exit.ml:18
_v1026 = {0}
_v1027 = 0
return
end
-- stdlib.ml:347
iter_560 = function(param_561) -- stdlib.ml:355
local _m119
local _m192
local _m197
local _m207
local _m217
local _m222
local _m235
local _m256
local _m257
local _m282
local _m302
_m119 = function(param_893, _v894) -- stdlib.ml:567
_v895 = 0
_v896 = old_exit_884(_v895)
return _v896
end
_m192 = function(len_709, ofs_710, s_711, ic_712, _v713) -- stdlib.ml:435
_v715 = invalid_arg_349(_v714)
return _v715
end
_m197 = function(len_679, ofs_680, s_681, ic_682, _v683) -- stdlib.ml:422
_v685 = invalid_arg_349(_v684)
return _v685
end
_m207 = function(oc_644, _v645) -- stdlib.ml:395
local _ok, _res = pcall(function() _v649 = 0
-- stdlib.ml:395
return _v649
end)
if _ok then
exn_648 = _res
else
exn_648 = _res
-- stdlib.ml:395
_v650 = caml_ml_close_channel(oc_644)
-- stdlib.ml:395
end
end
_m217 = function(len_622, ofs_623, s_624, oc_625, _v626) -- stdlib.ml:378
_v628 = invalid_arg_349(_v627)
return _v628
end
_m222 = function(len_604, ofs_605, s_606, oc_607, _v608) -- stdlib.ml:373
_v610 = invalid_arg_349(_v609)
return _v610
end
_m235 = function(param_572, l_573, a_574, _v575) -- stdlib.ml:355
_v576 = iter_560(l_573)
return _v576
end
_m256 = function(i_467, match_468, _v469) -- stdlib.ml:283
return s_457
end
_m257 = function(i_470, match_471, _v472) -- stdlib.ml:282
_v473 = 2
_v474 = int_add(i_470, _v473)
_v475 = loop_459(_v474)
return _v475
end
_m282 = function(n_416, n_417) -- stdlib.ml:224
_v419 = invalid_arg_349(_v418)
return _v419
end
_m302 = function(greet_1018, x_1019, match_1020) _v1021 = {0, greet_1018}
_v1022 = 0
_v1023 = 0
_v1024 = _v1000[104]
-- std_exit.ml:18
_v1025 = _v1024(_v1023)
-- std_exit.ml:18
_v1026 = {0}
_v1027 = 0
return
end
-- stdlib.ml:347
if param_561 then
l_562 = param_561[3]
a_563 = param_561[2]
-- stdlib.ml:350
local _ok, _res = pcall(function() tag_569 = exn_568[2]
_v570 = tag_569 == Sys_error_361
if _v570 then
-- stdlib.ml:353
_v571 = 0
-- stdlib.ml:355
return _m235(param_564, l_565, a_566, _v571)
else
error(exn_568)
end
end)
if _ok then
exn_568 = _res
else
exn_568 = _res
-- stdlib.ml:351
_v577 = caml_ml_flush(a_563)
-- stdlib.ml:351
end
else
-- stdlib.ml:348
_v578 = 0
return _v578
end
end
-- stdlib.ml:356
_v579 = 0
-- stdlib.ml:356
_v580 = caml_ml_out_channels_list(_v579)
-- stdlib.ml:356
_v581 = iter_560(_v580)
return _v581
end
output_bytes_582 = function(oc_584, s_583) -- stdlib.ml:366
local _m119
local _m192
local _m197
local _m207
local _m217
local _m222
local _m235
local _m256
local _m257
local _m282
local _m302
_m119 = function(param_893, _v894) -- stdlib.ml:567
_v895 = 0
_v896 = old_exit_884(_v895)
return _v896
end
_m192 = function(len_709, ofs_710, s_711, ic_712, _v713) -- stdlib.ml:435
_v715 = invalid_arg_349(_v714)
return _v715
end
_m197 = function(len_679, ofs_680, s_681, ic_682, _v683) -- stdlib.ml:422
_v685 = invalid_arg_349(_v684)
return _v685
end
_m207 = function(oc_644, _v645) -- stdlib.ml:395
local _ok, _res = pcall(function() _v649 = 0
-- stdlib.ml:395
return _v649
end)
if _ok then
exn_648 = _res
else
exn_648 = _res
-- stdlib.ml:395
_v650 = caml_ml_close_channel(oc_644)
-- stdlib.ml:395
end
end
_m217 = function(len_622, ofs_623, s_624, oc_625, _v626) -- stdlib.ml:378
_v628 = invalid_arg_349(_v627)
return _v628
end
_m222 = function(len_604, ofs_605, s_606, oc_607, _v608) -- stdlib.ml:373
_v610 = invalid_arg_349(_v609)
return _v610
end
_m235 = function(param_572, l_573, a_574, _v575) -- stdlib.ml:355
_v576 = iter_560(l_573)
return _v576
end
_m256 = function(i_467, match_468, _v469) -- stdlib.ml:283
return s_457
end
_m257 = function(i_470, match_471, _v472) -- stdlib.ml:282
_v473 = 2
_v474 = int_add(i_470, _v473)
_v475 = loop_459(_v474)
return _v475
end
_m282 = function(n_416, n_417) -- stdlib.ml:224
_v419 = invalid_arg_349(_v418)
return _v419
end
_m302 = function(greet_1018, x_1019, match_1020) _v1021 = {0, greet_1018}
_v1022 = 0
_v1023 = 0
_v1024 = _v1000[104]
-- std_exit.ml:18
_v1025 = _v1024(_v1023)
-- std_exit.ml:18
_v1026 = {0}
_v1027 = 0
return
end
-- stdlib.ml:366
_v585 = caml_ml_bytes_length(s_583)
_v586 = 0
-- stdlib.ml:366
_v587 = caml_ml_output_bytes(oc_584, s_583, _v586, _v585)
-- stdlib.ml:366
return _v587
end
output_string_588 = function(oc_590, s_589) -- stdlib.ml:369
local _m119
local _m192
local _m197
local _m207
local _m217
local _m222
local _m235
local _m256
local _m257
local _m282
local _m302
_m119 = function(param_893, _v894) -- stdlib.ml:567
_v895 = 0
_v896 = old_exit_884(_v895)
return _v896
end
_m192 = function(len_709, ofs_710, s_711, ic_712, _v713) -- stdlib.ml:435
_v715 = invalid_arg_349(_v714)
return _v715
end
_m197 = function(len_679, ofs_680, s_681, ic_682, _v683) -- stdlib.ml:422
_v685 = invalid_arg_349(_v684)
return _v685
end
_m207 = function(oc_644, _v645) -- stdlib.ml:395
local _ok, _res = pcall(function() _v649 = 0
-- stdlib.ml:395
return _v649
end)
if _ok then
exn_648 = _res
else
exn_648 = _res
-- stdlib.ml:395
_v650 = caml_ml_close_channel(oc_644)
-- stdlib.ml:395
end
end
_m217 = function(len_622, ofs_623, s_624, oc_625, _v626) -- stdlib.ml:378
_v628 = invalid_arg_349(_v627)
return _v628
end
_m222 = function(len_604, ofs_605, s_606, oc_607, _v608) -- stdlib.ml:373
_v610 = invalid_arg_349(_v609)
return _v610
end
_m235 = function(param_572, l_573, a_574, _v575) -- stdlib.ml:355
_v576 = iter_560(l_573)
return _v576
end
_m256 = function(i_467, match_468, _v469) -- stdlib.ml:283
return s_457
end
_m257 = function(i_470, match_471, _v472) -- stdlib.ml:282
_v473 = 2
_v474 = int_add(i_470, _v473)
_v475 = loop_459(_v474)
return _v475
end
_m282 = function(n_416, n_417) -- stdlib.ml:224
_v419 = invalid_arg_349(_v418)
return _v419
end
_m302 = function(greet_1018, x_1019, match_1020) _v1021 = {0, greet_1018}
_v1022 = 0
_v1023 = 0
_v1024 = _v1000[104]
-- std_exit.ml:18
_v1025 = _v1024(_v1023)
-- std_exit.ml:18
_v1026 = {0}
_v1027 = 0
return
end
-- stdlib.ml:369
_v591 = caml_ml_string_length(s_589)
_v592 = 0
-- stdlib.ml:369
_v593 = caml_ml_output(oc_590, s_589, _v592, _v591)
-- stdlib.ml:369
return _v593
end
output_594 = function(oc_598, s_597, ofs_596, len_595) -- stdlib.ml:374
local _m119
local _m192
local _m197
local _m207
local _m217
local _m222
local _m235
local _m256
local _m257
local _m282
local _m302
_m119 = function(param_893, _v894) -- stdlib.ml:567
_v895 = 0
_v896 = old_exit_884(_v895)
return _v896
end
_m192 = function(len_709, ofs_710, s_711, ic_712, _v713) -- stdlib.ml:435
_v715 = invalid_arg_349(_v714)
return _v715
end
_m197 = function(len_679, ofs_680, s_681, ic_682, _v683) -- stdlib.ml:422
_v685 = invalid_arg_349(_v684)
return _v685
end
_m207 = function(oc_644, _v645) -- stdlib.ml:395
local _ok, _res = pcall(function() _v649 = 0
-- stdlib.ml:395
return _v649
end)
if _ok then
exn_648 = _res
else
exn_648 = _res
-- stdlib.ml:395
_v650 = caml_ml_close_channel(oc_644)
-- stdlib.ml:395
end
end
_m217 = function(len_622, ofs_623, s_624, oc_625, _v626) -- stdlib.ml:378
_v628 = invalid_arg_349(_v627)
return _v628
end
_m222 = function(len_604, ofs_605, s_606, oc_607, _v608) -- stdlib.ml:373
_v610 = invalid_arg_349(_v609)
return _v610
end
_m235 = function(param_572, l_573, a_574, _v575) -- stdlib.ml:355
_v576 = iter_560(l_573)
return _v576
end
_m256 = function(i_467, match_468, _v469) -- stdlib.ml:283
return s_457
end
_m257 = function(i_470, match_471, _v472) -- stdlib.ml:282
_v473 = 2
_v474 = int_add(i_470, _v473)
_v475 = loop_459(_v474)
return _v475
end
_m282 = function(n_416, n_417) -- stdlib.ml:224
_v419 = invalid_arg_349(_v418)
return _v419
end
_m302 = function(greet_1018, x_1019, match_1020) _v1021 = {0, greet_1018}
_v1022 = 0
_v1023 = 0
_v1024 = _v1000[104]
-- std_exit.ml:18
_v1025 = _v1024(_v1023)
-- std_exit.ml:18
_v1026 = {0}
_v1027 = 0
return
end
-- stdlib.ml:372
_v599 = 0 <= ofs_596
if _v599 then
_v600 = 0 <= len_595
if _v600 then
_v601 = caml_ml_bytes_length(s_597)
_v602 = int_sub(_v601, len_595)
_v603 = _v602 < ofs_596
if _v603 then
return _m222(len_595, ofs_596, s_597, oc_598, _v603)
else
-- stdlib.ml:374
_v611 = caml_ml_output_bytes(oc_598, s_597, ofs_596, len_595)
-- stdlib.ml:374
return _v611
end
else
return _m222(len_595, ofs_596, s_597, oc_598, len_595)
end
else
return _m222(len_595, ofs_596, s_597, oc_598, ofs_596)
end
end
output_substring_612 = function(oc_616, s_615, ofs_614, len_613) -- stdlib.ml:379
local _m119
local _m192
local _m197
local _m207
local _m217
local _m222
local _m235
local _m256
local _m257
local _m282
local _m302
_m119 = function(param_893, _v894) -- stdlib.ml:567
_v895 = 0
_v896 = old_exit_884(_v895)
return _v896
end
_m192 = function(len_709, ofs_710, s_711, ic_712, _v713) -- stdlib.ml:435
_v715 = invalid_arg_349(_v714)
return _v715
end
_m197 = function(len_679, ofs_680, s_681, ic_682, _v683) -- stdlib.ml:422
_v685 = invalid_arg_349(_v684)
return _v685
end
_m207 = function(oc_644, _v645) -- stdlib.ml:395
local _ok, _res = pcall(function() _v649 = 0
-- stdlib.ml:395
return _v649
end)
if _ok then
exn_648 = _res
else
exn_648 = _res
-- stdlib.ml:395
_v650 = caml_ml_close_channel(oc_644)
-- stdlib.ml:395
end
end
_m217 = function(len_622, ofs_623, s_624, oc_625, _v626) -- stdlib.ml:378
_v628 = invalid_arg_349(_v627)
return _v628
end
_m222 = function(len_604, ofs_605, s_606, oc_607, _v608) -- stdlib.ml:373
_v610 = invalid_arg_349(_v609)
return _v610
end
_m235 = function(param_572, l_573, a_574, _v575) -- stdlib.ml:355
_v576 = iter_560(l_573)
return _v576
end
_m256 = function(i_467, match_468, _v469) -- stdlib.ml:283
return s_457
end
_m257 = function(i_470, match_471, _v472) -- stdlib.ml:282
_v473 = 2
_v474 = int_add(i_470, _v473)
_v475 = loop_459(_v474)
return _v475
end
_m282 = function(n_416, n_417) -- stdlib.ml:224
_v419 = invalid_arg_349(_v418)
return _v419
end
_m302 = function(greet_1018, x_1019, match_1020) _v1021 = {0, greet_1018}
_v1022 = 0
_v1023 = 0
_v1024 = _v1000[104]
-- std_exit.ml:18
_v1025 = _v1024(_v1023)
-- std_exit.ml:18
_v1026 = {0}
_v1027 = 0
return
end
-- stdlib.ml:377
_v617 = 0 <= ofs_614
if _v617 then
_v618 = 0 <= len_613
if _v618 then
_v619 = caml_ml_string_length(s_615)
_v620 = int_sub(_v619, len_613)
_v621 = _v620 < ofs_614
if _v621 then
return _m217(len_613, ofs_614, s_615, oc_616, _v621)
else
-- stdlib.ml:379
_v629 = caml_ml_output(oc_616, s_615, ofs_614, len_613)
-- stdlib.ml:379
return _v629
end
else
return _m217(len_613, ofs_614, s_615, oc_616, len_613)
end
else
return _m217(len_613, ofs_614, s_615, oc_616, ofs_614)
end
end
output_value_630 = function(chan_632, v_631) -- stdlib.ml:386
local _m119
local _m192
local _m197
local _m207
local _m217
local _m222
local _m235
local _m256
local _m257
local _m282
local _m302
_m119 = function(param_893, _v894) -- stdlib.ml:567
_v895 = 0
_v896 = old_exit_884(_v895)
return _v896
end
_m192 = function(len_709, ofs_710, s_711, ic_712, _v713) -- stdlib.ml:435
_v715 = invalid_arg_349(_v714)
return _v715
end
_m197 = function(len_679, ofs_680, s_681, ic_682, _v683) -- stdlib.ml:422
_v685 = invalid_arg_349(_v684)
return _v685
end
_m207 = function(oc_644, _v645) -- stdlib.ml:395
local _ok, _res = pcall(function() _v649 = 0
-- stdlib.ml:395
return _v649
end)
if _ok then
exn_648 = _res
else
exn_648 = _res
-- stdlib.ml:395
_v650 = caml_ml_close_channel(oc_644)
-- stdlib.ml:395
end
end
_m217 = function(len_622, ofs_623, s_624, oc_625, _v626) -- stdlib.ml:378
_v628 = invalid_arg_349(_v627)
return _v628
end
_m222 = function(len_604, ofs_605, s_606, oc_607, _v608) -- stdlib.ml:373
_v610 = invalid_arg_349(_v609)
return _v610
end
_m235 = function(param_572, l_573, a_574, _v575) -- stdlib.ml:355
_v576 = iter_560(l_573)
return _v576
end
_m256 = function(i_467, match_468, _v469) -- stdlib.ml:283
return s_457
end
_m257 = function(i_470, match_471, _v472) -- stdlib.ml:282
_v473 = 2
_v474 = int_add(i_470, _v473)
_v475 = loop_459(_v474)
return _v475
end
_m282 = function(n_416, n_417) -- stdlib.ml:224
_v419 = invalid_arg_349(_v418)
return _v419
end
_m302 = function(greet_1018, x_1019, match_1020) _v1021 = {0, greet_1018}
_v1022 = 0
_v1023 = 0
_v1024 = _v1000[104]
-- std_exit.ml:18
_v1025 = _v1024(_v1023)
-- std_exit.ml:18
_v1026 = {0}
_v1027 = 0
return
end
-- stdlib.ml:386
_v633 = 0
-- stdlib.ml:386
_v634 = caml_output_value(chan_632, v_631, _v633)
-- stdlib.ml:386
return _v634
end
close_out_635 = function(oc_636) -- stdlib.ml:392
local _m119
local _m192
local _m197
local _m207
local _m217
local _m222
local _m235
local _m256
local _m257
local _m282
local _m302
_m119 = function(param_893, _v894) -- stdlib.ml:567
_v895 = 0
_v896 = old_exit_884(_v895)
return _v896
end
_m192 = function(len_709, ofs_710, s_711, ic_712, _v713) -- stdlib.ml:435
_v715 = invalid_arg_349(_v714)
return _v715
end
_m197 = function(len_679, ofs_680, s_681, ic_682, _v683) -- stdlib.ml:422
_v685 = invalid_arg_349(_v684)
return _v685
end
_m207 = function(oc_644, _v645) -- stdlib.ml:395
local _ok, _res = pcall(function() _v649 = 0
-- stdlib.ml:395
return _v649
end)
if _ok then
exn_648 = _res
else
exn_648 = _res
-- stdlib.ml:395
_v650 = caml_ml_close_channel(oc_644)
-- stdlib.ml:395
end
end
_m217 = function(len_622, ofs_623, s_624, oc_625, _v626) -- stdlib.ml:378
_v628 = invalid_arg_349(_v627)
return _v628
end
_m222 = function(len_604, ofs_605, s_606, oc_607, _v608) -- stdlib.ml:373
_v610 = invalid_arg_349(_v609)
return _v610
end
_m235 = function(param_572, l_573, a_574, _v575) -- stdlib.ml:355
_v576 = iter_560(l_573)
return _v576
end
_m256 = function(i_467, match_468, _v469) -- stdlib.ml:283
return s_457
end
_m257 = function(i_470, match_471, _v472) -- stdlib.ml:282
_v473 = 2
_v474 = int_add(i_470, _v473)
_v475 = loop_459(_v474)
return _v475
end
_m282 = function(n_416, n_417) -- stdlib.ml:224
_v419 = invalid_arg_349(_v418)
return _v419
end
_m302 = function(greet_1018, x_1019, match_1020) _v1021 = {0, greet_1018}
_v1022 = 0
_v1023 = 0
_v1024 = _v1000[104]
-- std_exit.ml:18
_v1025 = _v1024(_v1023)
-- std_exit.ml:18
_v1026 = {0}
_v1027 = 0
return
end
-- stdlib.ml:392
_v637 = caml_ml_flush(oc_636)
-- stdlib.ml:392
_v638 = caml_ml_close_channel(oc_636)
-- stdlib.ml:392
return _v638
end
close_out_noerr_639 = function(oc_640) -- stdlib.ml:395
local _m119
local _m192
local _m197
local _m207
local _m217
local _m222
local _m235
local _m256
local _m257
local _m282
local _m302
_m119 = function(param_893, _v894) -- stdlib.ml:567
_v895 = 0
_v896 = old_exit_884(_v895)
return _v896
end
_m192 = function(len_709, ofs_710, s_711, ic_712, _v713) -- stdlib.ml:435
_v715 = invalid_arg_349(_v714)
return _v715
end
_m197 = function(len_679, ofs_680, s_681, ic_682, _v683) -- stdlib.ml:422
_v685 = invalid_arg_349(_v684)
return _v685
end
_m207 = function(oc_644, _v645) -- stdlib.ml:395
local _ok, _res = pcall(function() _v649 = 0
-- stdlib.ml:395
return _v649
end)
if _ok then
exn_648 = _res
else
exn_648 = _res
-- stdlib.ml:395
_v650 = caml_ml_close_channel(oc_644)
-- stdlib.ml:395
end
end
_m217 = function(len_622, ofs_623, s_624, oc_625, _v626) -- stdlib.ml:378
_v628 = invalid_arg_349(_v627)
return _v628
end
_m222 = function(len_604, ofs_605, s_606, oc_607, _v608) -- stdlib.ml:373
_v610 = invalid_arg_349(_v609)
return _v610
end
_m235 = function(param_572, l_573, a_574, _v575) -- stdlib.ml:355
_v576 = iter_560(l_573)
return _v576
end
_m256 = function(i_467, match_468, _v469) -- stdlib.ml:283
return s_457
end
_m257 = function(i_470, match_471, _v472) -- stdlib.ml:282
_v473 = 2
_v474 = int_add(i_470, _v473)
_v475 = loop_459(_v474)
return _v475
end
_m282 = function(n_416, n_417) -- stdlib.ml:224
_v419 = invalid_arg_349(_v418)
return _v419
end
_m302 = function(greet_1018, x_1019, match_1020) _v1021 = {0, greet_1018}
_v1022 = 0
_v1023 = 0
_v1024 = _v1000[104]
-- std_exit.ml:18
_v1025 = _v1024(_v1023)
-- std_exit.ml:18
_v1026 = {0}
_v1027 = 0
return
end
-- stdlib.ml:394
local _ok, _res = pcall(function() _v643 = 0
-- stdlib.ml:395
return _m207(oc_641, _v643)
end)
if _ok then
exn_642 = _res
else
exn_642 = _res
-- stdlib.ml:394
_v651 = caml_ml_flush(oc_640)
-- stdlib.ml:394
end
end
open_in_gen_652 = function(mode_655, perm_654, name_653) -- stdlib.ml:407
local _m119
local _m192
local _m197
local _m207
local _m217
local _m222
local _m235
local _m256
local _m257
local _m282
local _m302
_m119 = function(param_893, _v894) -- stdlib.ml:567
_v895 = 0
_v896 = old_exit_884(_v895)
return _v896
end
_m192 = function(len_709, ofs_710, s_711, ic_712, _v713) -- stdlib.ml:435
_v715 = invalid_arg_349(_v714)
return _v715
end
_m197 = function(len_679, ofs_680, s_681, ic_682, _v683) -- stdlib.ml:422
_v685 = invalid_arg_349(_v684)
return _v685
end
_m207 = function(oc_644, _v645) -- stdlib.ml:395
local _ok, _res = pcall(function() _v649 = 0
-- stdlib.ml:395
return _v649
end)
if _ok then
exn_648 = _res
else
exn_648 = _res
-- stdlib.ml:395
_v650 = caml_ml_close_channel(oc_644)
-- stdlib.ml:395
end
end
_m217 = function(len_622, ofs_623, s_624, oc_625, _v626) -- stdlib.ml:378
_v628 = invalid_arg_349(_v627)
return _v628
end
_m222 = function(len_604, ofs_605, s_606, oc_607, _v608) -- stdlib.ml:373
_v610 = invalid_arg_349(_v609)
return _v610
end
_m235 = function(param_572, l_573, a_574, _v575) -- stdlib.ml:355
_v576 = iter_560(l_573)
return _v576
end
_m256 = function(i_467, match_468, _v469) -- stdlib.ml:283
return s_457
end
_m257 = function(i_470, match_471, _v472) -- stdlib.ml:282
_v473 = 2
_v474 = int_add(i_470, _v473)
_v475 = loop_459(_v474)
return _v475
end
_m282 = function(n_416, n_417) -- stdlib.ml:224
_v419 = invalid_arg_349(_v418)
return _v419
end
_m302 = function(greet_1018, x_1019, match_1020) _v1021 = {0, greet_1018}
_v1022 = 0
_v1023 = 0
_v1024 = _v1000[104]
-- std_exit.ml:18
_v1025 = _v1024(_v1023)
-- std_exit.ml:18
_v1026 = {0}
_v1027 = 0
return
end
-- stdlib.ml:405
_v656 = caml_sys_open(name_653, mode_655, perm_654)
-- stdlib.ml:405
c_657 = caml_ml_open_descriptor_in(_v656)
-- stdlib.ml:406
_v658 = caml_ml_set_channel_name(c_657, name_653)
-- stdlib.ml:406
return c_657
end
open_in_659 = function(name_660) -- stdlib.ml:410
local _m119
local _m192
local _m197
local _m207
local _m217
local _m222
local _m235
local _m256
local _m257
local _m282
local _m302
_m119 = function(param_893, _v894) -- stdlib.ml:567
_v895 = 0
_v896 = old_exit_884(_v895)
return _v896
end
_m192 = function(len_709, ofs_710, s_711, ic_712, _v713) -- stdlib.ml:435
_v715 = invalid_arg_349(_v714)
return _v715
end
_m197 = function(len_679, ofs_680, s_681, ic_682, _v683) -- stdlib.ml:422
_v685 = invalid_arg_349(_v684)
return _v685
end
_m207 = function(oc_644, _v645) -- stdlib.ml:395
local _ok, _res = pcall(function() _v649 = 0
-- stdlib.ml:395
return _v649
end)
if _ok then
exn_648 = _res
else
exn_648 = _res
-- stdlib.ml:395
_v650 = caml_ml_close_channel(oc_644)
-- stdlib.ml:395
end
end
_m217 = function(len_622, ofs_623, s_624, oc_625, _v626) -- stdlib.ml:378
_v628 = invalid_arg_349(_v627)
return _v628
end
_m222 = function(len_604, ofs_605, s_606, oc_607, _v608) -- stdlib.ml:373
_v610 = invalid_arg_349(_v609)
return _v610
end
_m235 = function(param_572, l_573, a_574, _v575) -- stdlib.ml:355
_v576 = iter_560(l_573)
return _v576
end
_m256 = function(i_467, match_468, _v469) -- stdlib.ml:283
return s_457
end
_m257 = function(i_470, match_471, _v472) -- stdlib.ml:282
_v473 = 2
_v474 = int_add(i_470, _v473)
_v475 = loop_459(_v474)
return _v475
end
_m282 = function(n_416, n_417) -- stdlib.ml:224
_v419 = invalid_arg_349(_v418)
return _v419
end
_m302 = function(greet_1018, x_1019, match_1020) _v1021 = {0, greet_1018}
_v1022 = 0
_v1023 = 0
_v1024 = _v1000[104]
-- std_exit.ml:18
_v1025 = _v1024(_v1023)
-- std_exit.ml:18
_v1026 = {0}
_v1027 = 0
return
end
-- stdlib.ml:410
_v661 = 0
_v663 = open_in_gen_652(_v662, _v661, name_660)
return _v663
end
open_in_bin_664 = function(name_665) -- stdlib.ml:413
local _m119
local _m192
local _m197
local _m207
local _m217
local _m222
local _m235
local _m256
local _m257
local _m282
local _m302
_m119 = function(param_893, _v894) -- stdlib.ml:567
_v895 = 0
_v896 = old_exit_884(_v895)
return _v896
end
_m192 = function(len_709, ofs_710, s_711, ic_712, _v713) -- stdlib.ml:435
_v715 = invalid_arg_349(_v714)
return _v715
end
_m197 = function(len_679, ofs_680, s_681, ic_682, _v683) -- stdlib.ml:422
_v685 = invalid_arg_349(_v684)
return _v685
end
_m207 = function(oc_644, _v645) -- stdlib.ml:395
local _ok, _res = pcall(function() _v649 = 0
-- stdlib.ml:395
return _v649
end)
if _ok then
exn_648 = _res
else
exn_648 = _res
-- stdlib.ml:395
_v650 = caml_ml_close_channel(oc_644)
-- stdlib.ml:395
end
end
_m217 = function(len_622, ofs_623, s_624, oc_625, _v626) -- stdlib.ml:378
_v628 = invalid_arg_349(_v627)
return _v628
end
_m222 = function(len_604, ofs_605, s_606, oc_607, _v608) -- stdlib.ml:373
_v610 = invalid_arg_349(_v609)
return _v610
end
_m235 = function(param_572, l_573, a_574, _v575) -- stdlib.ml:355
_v576 = iter_560(l_573)
return _v576
end
_m256 = function(i_467, match_468, _v469) -- stdlib.ml:283
return s_457
end
_m257 = function(i_470, match_471, _v472) -- stdlib.ml:282
_v473 = 2
_v474 = int_add(i_470, _v473)
_v475 = loop_459(_v474)
return _v475
end
_m282 = function(n_416, n_417) -- stdlib.ml:224
_v419 = invalid_arg_349(_v418)
return _v419
end
_m302 = function(greet_1018, x_1019, match_1020) _v1021 = {0, greet_1018}
_v1022 = 0
_v1023 = 0
_v1024 = _v1000[104]
-- std_exit.ml:18
_v1025 = _v1024(_v1023)
-- std_exit.ml:18
_v1026 = {0}
_v1027 = 0
return
end
-- stdlib.ml:413
_v666 = 0
_v668 = open_in_gen_652(_v667, _v666, name_665)
return _v668
end
input_669 = function(ic_673, s_672, ofs_671, len_670) -- stdlib.ml:423
local _m119
local _m192
local _m197
local _m207
local _m217
local _m222
local _m235
local _m256
local _m257
local _m282
local _m302
_m119 = function(param_893, _v894) -- stdlib.ml:567
_v895 = 0
_v896 = old_exit_884(_v895)
return _v896
end
_m192 = function(len_709, ofs_710, s_711, ic_712, _v713) -- stdlib.ml:435
_v715 = invalid_arg_349(_v714)
return _v715
end
_m197 = function(len_679, ofs_680, s_681, ic_682, _v683) -- stdlib.ml:422
_v685 = invalid_arg_349(_v684)
return _v685
end
_m207 = function(oc_644, _v645) -- stdlib.ml:395
local _ok, _res = pcall(function() _v649 = 0
-- stdlib.ml:395
return _v649
end)
if _ok then
exn_648 = _res
else
exn_648 = _res
-- stdlib.ml:395
_v650 = caml_ml_close_channel(oc_644)
-- stdlib.ml:395
end
end
_m217 = function(len_622, ofs_623, s_624, oc_625, _v626) -- stdlib.ml:378
_v628 = invalid_arg_349(_v627)
return _v628
end
_m222 = function(len_604, ofs_605, s_606, oc_607, _v608) -- stdlib.ml:373
_v610 = invalid_arg_349(_v609)
return _v610
end
_m235 = function(param_572, l_573, a_574, _v575) -- stdlib.ml:355
_v576 = iter_560(l_573)
return _v576
end
_m256 = function(i_467, match_468, _v469) -- stdlib.ml:283
return s_457
end
_m257 = function(i_470, match_471, _v472) -- stdlib.ml:282
_v473 = 2
_v474 = int_add(i_470, _v473)
_v475 = loop_459(_v474)
return _v475
end
_m282 = function(n_416, n_417) -- stdlib.ml:224
_v419 = invalid_arg_349(_v418)
return _v419
end
_m302 = function(greet_1018, x_1019, match_1020) _v1021 = {0, greet_1018}
_v1022 = 0
_v1023 = 0
_v1024 = _v1000[104]
-- std_exit.ml:18
_v1025 = _v1024(_v1023)
-- std_exit.ml:18
_v1026 = {0}
_v1027 = 0
return
end
-- stdlib.ml:421
_v674 = 0 <= ofs_671
if _v674 then
_v675 = 0 <= len_670
if _v675 then
_v676 = caml_ml_bytes_length(s_672)
_v677 = int_sub(_v676, len_670)
_v678 = _v677 < ofs_671
if _v678 then
return _m197(len_670, ofs_671, s_672, ic_673, _v678)
else
-- stdlib.ml:423
_v686 = caml_ml_input(ic_673, s_672, ofs_671, len_670)
-- stdlib.ml:423
return _v686
end
else
return _m197(len_670, ofs_671, s_672, ic_673, len_670)
end
else
return _m197(len_670, ofs_671, s_672, ic_673, ofs_671)
end
end
unsafe_really_input_687 = function(ic_691, s_690, ofs_689, len_688) -- stdlib.ml:431
local _m119
local _m192
local _m197
local _m207
local _m217
local _m222
local _m235
local _m256
local _m257
local _m282
local _m302
_m119 = function(param_893, _v894) -- stdlib.ml:567
_v895 = 0
_v896 = old_exit_884(_v895)
return _v896
end
_m192 = function(len_709, ofs_710, s_711, ic_712, _v713) -- stdlib.ml:435
_v715 = invalid_arg_349(_v714)
return _v715
end
_m197 = function(len_679, ofs_680, s_681, ic_682, _v683) -- stdlib.ml:422
_v685 = invalid_arg_349(_v684)
return _v685
end
_m207 = function(oc_644, _v645) -- stdlib.ml:395
local _ok, _res = pcall(function() _v649 = 0
-- stdlib.ml:395
return _v649
end)
if _ok then
exn_648 = _res
else
exn_648 = _res
-- stdlib.ml:395
_v650 = caml_ml_close_channel(oc_644)
-- stdlib.ml:395
end
end
_m217 = function(len_622, ofs_623, s_624, oc_625, _v626) -- stdlib.ml:378
_v628 = invalid_arg_349(_v627)
return _v628
end
_m222 = function(len_604, ofs_605, s_606, oc_607, _v608) -- stdlib.ml:373
_v610 = invalid_arg_349(_v609)
return _v610
end
_m235 = function(param_572, l_573, a_574, _v575) -- stdlib.ml:355
_v576 = iter_560(l_573)
return _v576
end
_m256 = function(i_467, match_468, _v469) -- stdlib.ml:283
return s_457
end
_m257 = function(i_470, match_471, _v472) -- stdlib.ml:282
_v473 = 2
_v474 = int_add(i_470, _v473)
_v475 = loop_459(_v474)
return _v475
end
_m282 = function(n_416, n_417) -- stdlib.ml:224
_v419 = invalid_arg_349(_v418)
return _v419
end
_m302 = function(greet_1018, x_1019, match_1020) _v1021 = {0, greet_1018}
_v1022 = 0
_v1023 = 0
_v1024 = _v1000[104]
-- std_exit.ml:18
_v1025 = _v1024(_v1023)
-- std_exit.ml:18
_v1026 = {0}
_v1027 = 0
return
end
-- stdlib.ml:426
_v692 = 0 < len_688
if _v692 then
-- stdlib.ml:427
r_693 = caml_ml_input(ic_691, s_690, ofs_689, len_688)
-- stdlib.ml:428
_v694 = 0 == r_693
if _v694 then
-- stdlib.ml:429
error(End_of_file_362)
else
-- stdlib.ml:430
_v695 = int_sub(len_688, r_693)
_v696 = int_add(ofs_689, r_693)
_v697 = unsafe_really_input_687(ic_691, s_690, _v696, _v695)
return _v697
end
else
-- stdlib.ml:426
_v698 = 0
return _v698
end
end
really_input_699 = function(ic_703, s_702, ofs_701, len_700) -- stdlib.ml:436
local _m119
local _m192
local _m197
local _m207
local _m217
local _m222
local _m235
local _m256
local _m257
local _m282
local _m302
_m119 = function(param_893, _v894) -- stdlib.ml:567
_v895 = 0
_v896 = old_exit_884(_v895)
return _v896
end
_m192 = function(len_709, ofs_710, s_711, ic_712, _v713) -- stdlib.ml:435
_v715 = invalid_arg_349(_v714)
return _v715
end
_m197 = function(len_679, ofs_680, s_681, ic_682, _v683) -- stdlib.ml:422
_v685 = invalid_arg_349(_v684)
return _v685
end
_m207 = function(oc_644, _v645) -- stdlib.ml:395
local _ok, _res = pcall(function() _v649 = 0
-- stdlib.ml:395
return _v649
end)
if _ok then
exn_648 = _res
else
exn_648 = _res
-- stdlib.ml:395
_v650 = caml_ml_close_channel(oc_644)
-- stdlib.ml:395
end
end
_m217 = function(len_622, ofs_623, s_624, oc_625, _v626) -- stdlib.ml:378
_v628 = invalid_arg_349(_v627)
return _v628
end
_m222 = function(len_604, ofs_605, s_606, oc_607, _v608) -- stdlib.ml:373
_v610 = invalid_arg_349(_v609)
return _v610
end
_m235 = function(param_572, l_573, a_574, _v575) -- stdlib.ml:355
_v576 = iter_560(l_573)
return _v576
end
_m256 = function(i_467, match_468, _v469) -- stdlib.ml:283
return s_457
end
_m257 = function(i_470, match_471, _v472) -- stdlib.ml:282
_v473 = 2
_v474 = int_add(i_470, _v473)
_v475 = loop_459(_v474)
return _v475
end
_m282 = function(n_416, n_417) -- stdlib.ml:224
_v419 = invalid_arg_349(_v418)
return _v419
end
_m302 = function(greet_1018, x_1019, match_1020) _v1021 = {0, greet_1018}
_v1022 = 0
_v1023 = 0
_v1024 = _v1000[104]
-- std_exit.ml:18
_v1025 = _v1024(_v1023)
-- std_exit.ml:18
_v1026 = {0}
_v1027 = 0
return
end
-- stdlib.ml:434
_v704 = 0 <= ofs_701
if _v704 then
_v705 = 0 <= len_700
if _v705 then
_v706 = caml_ml_bytes_length(s_702)
_v707 = int_sub(_v706, len_700)
_v708 = _v707 < ofs_701
if _v708 then
return _m192(len_700, ofs_701, s_702, ic_703, _v708)
else
-- stdlib.ml:436
_v716 = unsafe_really_input_687(ic_703, s_702, ofs_701, len_700)
return _v716
end
else
return _m192(len_700, ofs_701, s_702, ic_703, len_700)
end
else
return _m192(len_700, ofs_701, s_702, ic_703, ofs_701)
end
end
really_input_string_717 = function(ic_719, len_718) -- stdlib.ml:441
local _m119
local _m192
local _m197
local _m207
local _m217
local _m222
local _m235
local _m256
local _m257
local _m282
local _m302
_m119 = function(param_893, _v894) -- stdlib.ml:567
_v895 = 0
_v896 = old_exit_884(_v895)
return _v896
end
_m192 = function(len_709, ofs_710, s_711, ic_712, _v713) -- stdlib.ml:435
_v715 = invalid_arg_349(_v714)
return _v715
end
_m197 = function(len_679, ofs_680, s_681, ic_682, _v683) -- stdlib.ml:422
_v685 = invalid_arg_349(_v684)
return _v685
end
_m207 = function(oc_644, _v645) -- stdlib.ml:395
local _ok, _res = pcall(function() _v649 = 0
-- stdlib.ml:395
return _v649
end)
if _ok then
exn_648 = _res
else
exn_648 = _res
-- stdlib.ml:395
_v650 = caml_ml_close_channel(oc_644)
-- stdlib.ml:395
end
end
_m217 = function(len_622, ofs_623, s_624, oc_625, _v626) -- stdlib.ml:378
_v628 = invalid_arg_349(_v627)
return _v628
end
_m222 = function(len_604, ofs_605, s_606, oc_607, _v608) -- stdlib.ml:373
_v610 = invalid_arg_349(_v609)
return _v610
end
_m235 = function(param_572, l_573, a_574, _v575) -- stdlib.ml:355
_v576 = iter_560(l_573)
return _v576
end
_m256 = function(i_467, match_468, _v469) -- stdlib.ml:283
return s_457
end
_m257 = function(i_470, match_471, _v472) -- stdlib.ml:282
_v473 = 2
_v474 = int_add(i_470, _v473)
_v475 = loop_459(_v474)
return _v475
end
_m282 = function(n_416, n_417) -- stdlib.ml:224
_v419 = invalid_arg_349(_v418)
return _v419
end
_m302 = function(greet_1018, x_1019, match_1020) _v1021 = {0, greet_1018}
_v1022 = 0
_v1023 = 0
_v1024 = _v1000[104]
-- std_exit.ml:18
_v1025 = _v1024(_v1023)
-- std_exit.ml:18
_v1026 = {0}
_v1027 = 0
return
end
-- stdlib.ml:439
s_720 = caml_create_bytes(len_718)
-- stdlib.ml:440
_v721 = 0
-- stdlib.ml:440
_v722 = really_input_699(ic_719, s_720, _v721, len_718)
-- stdlib.ml:440
_v723 = caml_string_of_bytes(s_720)
return _v723
end
input_line_724 = function(chan_725) -- stdlib.ml:471
local _m119
local _m192
local _m197
local _m207
local _m217
local _m222
local _m235
local _m256
local _m257
local _m282
local _m302
_m119 = function(param_893, _v894) -- stdlib.ml:567
_v895 = 0
_v896 = old_exit_884(_v895)
return _v896
end
_m192 = function(len_709, ofs_710, s_711, ic_712, _v713) -- stdlib.ml:435
_v715 = invalid_arg_349(_v714)
return _v715
end
_m197 = function(len_679, ofs_680, s_681, ic_682, _v683) -- stdlib.ml:422
_v685 = invalid_arg_349(_v684)
return _v685
end
_m207 = function(oc_644, _v645) -- stdlib.ml:395
local _ok, _res = pcall(function() _v649 = 0
-- stdlib.ml:395
return _v649
end)
if _ok then
exn_648 = _res
else
exn_648 = _res
-- stdlib.ml:395
_v650 = caml_ml_close_channel(oc_644)
-- stdlib.ml:395
end
end
_m217 = function(len_622, ofs_623, s_624, oc_625, _v626) -- stdlib.ml:378
_v628 = invalid_arg_349(_v627)
return _v628
end
_m222 = function(len_604, ofs_605, s_606, oc_607, _v608) -- stdlib.ml:373
_v610 = invalid_arg_349(_v609)
return _v610
end
_m235 = function(param_572, l_573, a_574, _v575) -- stdlib.ml:355
_v576 = iter_560(l_573)
return _v576
end
_m256 = function(i_467, match_468, _v469) -- stdlib.ml:283
return s_457
end
_m257 = function(i_470, match_471, _v472) -- stdlib.ml:282
_v473 = 2
_v474 = int_add(i_470, _v473)
_v475 = loop_459(_v474)
return _v475
end
_m282 = function(n_416, n_417) -- stdlib.ml:224
_v419 = invalid_arg_349(_v418)
return _v419
end
_m302 = function(greet_1018, x_1019, match_1020) _v1021 = {0, greet_1018}
_v1022 = 0
_v1023 = 0
_v1024 = _v1000[104]
-- std_exit.ml:18
_v1025 = _v1024(_v1023)
-- std_exit.ml:18
_v1026 = {0}
_v1027 = 0
return
end
-- stdlib.ml:446
build_result_726 = function(buf_729, pos_728, param_727) -- stdlib.ml:451
local _m119
local _m192
local _m197
local _m207
local _m217
local _m222
local _m235
local _m256
local _m257
local _m282
local _m302
_m119 = function(param_893, _v894) -- stdlib.ml:567
_v895 = 0
_v896 = old_exit_884(_v895)
return _v896
end
_m192 = function(len_709, ofs_710, s_711, ic_712, _v713) -- stdlib.ml:435
_v715 = invalid_arg_349(_v714)
return _v715
end
_m197 = function(len_679, ofs_680, s_681, ic_682, _v683) -- stdlib.ml:422
_v685 = invalid_arg_349(_v684)
return _v685
end
_m207 = function(oc_644, _v645) -- stdlib.ml:395
local _ok, _res = pcall(function() _v649 = 0
-- stdlib.ml:395
return _v649
end)
if _ok then
exn_648 = _res
else
exn_648 = _res
-- stdlib.ml:395
_v650 = caml_ml_close_channel(oc_644)
-- stdlib.ml:395
end
end
_m217 = function(len_622, ofs_623, s_624, oc_625, _v626) -- stdlib.ml:378
_v628 = invalid_arg_349(_v627)
return _v628
end
_m222 = function(len_604, ofs_605, s_606, oc_607, _v608) -- stdlib.ml:373
_v610 = invalid_arg_349(_v609)
return _v610
end
_m235 = function(param_572, l_573, a_574, _v575) -- stdlib.ml:355
_v576 = iter_560(l_573)
return _v576
end
_m256 = function(i_467, match_468, _v469) -- stdlib.ml:283
return s_457
end
_m257 = function(i_470, match_471, _v472) -- stdlib.ml:282
_v473 = 2
_v474 = int_add(i_470, _v473)
_v475 = loop_459(_v474)
return _v475
end
_m282 = function(n_416, n_417) -- stdlib.ml:224
_v419 = invalid_arg_349(_v418)
return _v419
end
_m302 = function(greet_1018, x_1019, match_1020) _v1021 = {0, greet_1018}
_v1022 = 0
_v1023 = 0
_v1024 = _v1000[104]
-- std_exit.ml:18
_v1025 = _v1024(_v1023)
-- std_exit.ml:18
_v1026 = {0}
_v1027 = 0
return
end
-- stdlib.ml:446
if param_727 then
tl_730 = param_727[3]
hd_731 = param_727[2]
-- stdlib.ml:449
len_732 = caml_ml_bytes_length(hd_731)
-- stdlib.ml:450
_v733 = int_sub(pos_728, len_732)
_v734 = 0
-- stdlib.ml:450
_v735 = caml_blit_bytes(hd_731, _v734, buf_729, _v733, len_732)
-- stdlib.ml:450
_v736 = int_sub(pos_728, len_732)
_v737 = build_result_726(buf_729, _v736, tl_730)
return _v737
else
-- stdlib.ml:447
return buf_729
end
end
-- stdlib.ml:452
scan_738 = function(accu_740, len_739) -- stdlib.ml:470
local _m119
local _m192
local _m197
local _m207
local _m217
local _m222
local _m235
local _m256
local _m257
local _m282
local _m302
_m119 = function(param_893, _v894) -- stdlib.ml:567
_v895 = 0
_v896 = old_exit_884(_v895)
return _v896
end
_m192 = function(len_709, ofs_710, s_711, ic_712, _v713) -- stdlib.ml:435
_v715 = invalid_arg_349(_v714)
return _v715
end
_m197 = function(len_679, ofs_680, s_681, ic_682, _v683) -- stdlib.ml:422
_v685 = invalid_arg_349(_v684)
return _v685
end
_m207 = function(oc_644, _v645) -- stdlib.ml:395
local _ok, _res = pcall(function() _v649 = 0
-- stdlib.ml:395
return _v649
end)
if _ok then
exn_648 = _res
else
exn_648 = _res
-- stdlib.ml:395
_v650 = caml_ml_close_channel(oc_644)
-- stdlib.ml:395
end
end
_m217 = function(len_622, ofs_623, s_624, oc_625, _v626) -- stdlib.ml:378
_v628 = invalid_arg_349(_v627)
return _v628
end
_m222 = function(len_604, ofs_605, s_606, oc_607, _v608) -- stdlib.ml:373
_v610 = invalid_arg_349(_v609)
return _v610
end
_m235 = function(param_572, l_573, a_574, _v575) -- stdlib.ml:355
_v576 = iter_560(l_573)
return _v576
end
_m256 = function(i_467, match_468, _v469) -- stdlib.ml:283
return s_457
end
_m257 = function(i_470, match_471, _v472) -- stdlib.ml:282
_v473 = 2
_v474 = int_add(i_470, _v473)
_v475 = loop_459(_v474)
return _v475
end
_m282 = function(n_416, n_417) -- stdlib.ml:224
_v419 = invalid_arg_349(_v418)
return _v419
end
_m302 = function(greet_1018, x_1019, match_1020) _v1021 = {0, greet_1018}
_v1022 = 0
_v1023 = 0
_v1024 = _v1000[104]
-- std_exit.ml:18
_v1025 = _v1024(_v1023)
-- std_exit.ml:18
_v1026 = {0}
_v1027 = 0
return
end
-- stdlib.ml:453
n_741 = caml_ml_input_scan_line(chan_725)
-- stdlib.ml:454
_v742 = 0 == n_741
if _v742 then
-- stdlib.ml:454
if accu_740 then
-- stdlib.ml:457
_v743 = caml_create_bytes(len_739)
-- stdlib.ml:457
_v744 = build_result_726(_v743, len_739, accu_740)
return _v744
else
-- stdlib.ml:456
error(End_of_file_362)
end
else
-- stdlib.ml:458
_v745 = 0 < n_741
if _v745 then
-- stdlib.ml:458
_v746 = -2
_v747 = int_add(n_741, _v746)
-- stdlib.ml:459
res_748 = caml_create_bytes(_v747)
-- stdlib.ml:460
_v749 = -2
_v750 = int_add(n_741, _v749)
_v751 = 0
-- stdlib.ml:460
_v752 = caml_ml_input(chan_725, res_748, _v751, _v750)
-- stdlib.ml:460
_v753 = 0
-- stdlib.ml:461
_v754 = caml_ml_input_char(chan_725)
-- stdlib.ml:461
_v755 = 0
-- stdlib.ml:462
if accu_740 then
-- stdlib.ml:464
_v756 = int_add(len_739, n_741)
_v757 = -2
len_758 = int_add(_v756, _v757)
-- stdlib.ml:465
_v759 = {0, res_748, accu_740}
-- stdlib.ml:465
_v760 = caml_create_bytes(len_758)
-- stdlib.ml:465
_v761 = build_result_726(_v760, len_758, _v759)
return _v761
else
-- stdlib.ml:463
return res_748
end
else
-- stdlib.ml:466
_v762 = int_neg(n_741)
-- stdlib.ml:467
beg_763 = caml_create_bytes(_v762)
-- stdlib.ml:468
_v764 = int_neg(n_741)
_v765 = 0
-- stdlib.ml:468
_v766 = caml_ml_input(chan_725, beg_763, _v765, _v764)
-- stdlib.ml:468
_v767 = 0
-- stdlib.ml:469
_v768 = int_sub(len_739, n_741)
_v769 = {0, beg_763, accu_740}
_v770 = scan_738(_v769, _v768)
return _v770
end
end
end
-- stdlib.ml:471
_v771 = 0
_v772 = 0
-- stdlib.ml:471
_v773 = scan_738(_v772, _v771)
-- stdlib.ml:471
_v774 = caml_string_of_bytes(_v773)
return _v774
end
close_in_noerr_775 = function(ic_776) -- stdlib.ml:480
local _m119
local _m192
local _m197
local _m207
local _m217
local _m222
local _m235
local _m256
local _m257
local _m282
local _m302
_m119 = function(param_893, _v894) -- stdlib.ml:567
_v895 = 0
_v896 = old_exit_884(_v895)
return _v896
end
_m192 = function(len_709, ofs_710, s_711, ic_712, _v713) -- stdlib.ml:435
_v715 = invalid_arg_349(_v714)
return _v715
end
_m197 = function(len_679, ofs_680, s_681, ic_682, _v683) -- stdlib.ml:422
_v685 = invalid_arg_349(_v684)
return _v685
end
_m207 = function(oc_644, _v645) -- stdlib.ml:395
local _ok, _res = pcall(function() _v649 = 0
-- stdlib.ml:395
return _v649
end)
if _ok then
exn_648 = _res
else
exn_648 = _res
-- stdlib.ml:395
_v650 = caml_ml_close_channel(oc_644)
-- stdlib.ml:395
end
end
_m217 = function(len_622, ofs_623, s_624, oc_625, _v626) -- stdlib.ml:378
_v628 = invalid_arg_349(_v627)
return _v628
end
_m222 = function(len_604, ofs_605, s_606, oc_607, _v608) -- stdlib.ml:373
_v610 = invalid_arg_349(_v609)
return _v610
end
_m235 = function(param_572, l_573, a_574, _v575) -- stdlib.ml:355
_v576 = iter_560(l_573)
return _v576
end
_m256 = function(i_467, match_468, _v469) -- stdlib.ml:283
return s_457
end
_m257 = function(i_470, match_471, _v472) -- stdlib.ml:282
_v473 = 2
_v474 = int_add(i_470, _v473)
_v475 = loop_459(_v474)
return _v475
end
_m282 = function(n_416, n_417) -- stdlib.ml:224
_v419 = invalid_arg_349(_v418)
return _v419
end
_m302 = function(greet_1018, x_1019, match_1020) _v1021 = {0, greet_1018}
_v1022 = 0
_v1023 = 0
_v1024 = _v1000[104]
-- std_exit.ml:18
_v1025 = _v1024(_v1023)
-- std_exit.ml:18
_v1026 = {0}
_v1027 = 0
return
end
-- stdlib.ml:480
local _ok, _res = pcall(function() _v779 = 0
-- stdlib.ml:480
return _v779
end)
if _ok then
exn_778 = _res
else
exn_778 = _res
-- stdlib.ml:480
_v780 = caml_ml_close_channel(ic_776)
-- stdlib.ml:480
end
end
print_char_781 = function(c_782) -- stdlib.ml:486
local _m119
local _m192
local _m197
local _m207
local _m217
local _m222
local _m235
local _m256
local _m257
local _m282
local _m302
_m119 = function(param_893, _v894) -- stdlib.ml:567
_v895 = 0
_v896 = old_exit_884(_v895)
return _v896
end
_m192 = function(len_709, ofs_710, s_711, ic_712, _v713) -- stdlib.ml:435
_v715 = invalid_arg_349(_v714)
return _v715
end
_m197 = function(len_679, ofs_680, s_681, ic_682, _v683) -- stdlib.ml:422
_v685 = invalid_arg_349(_v684)
return _v685
end
_m207 = function(oc_644, _v645) -- stdlib.ml:395
local _ok, _res = pcall(function() _v649 = 0
-- stdlib.ml:395
return _v649
end)
if _ok then
exn_648 = _res
else
exn_648 = _res
-- stdlib.ml:395
_v650 = caml_ml_close_channel(oc_644)
-- stdlib.ml:395
end
end
_m217 = function(len_622, ofs_623, s_624, oc_625, _v626) -- stdlib.ml:378
_v628 = invalid_arg_349(_v627)
return _v628
end
_m222 = function(len_604, ofs_605, s_606, oc_607, _v608) -- stdlib.ml:373
_v610 = invalid_arg_349(_v609)
return _v610
end
_m235 = function(param_572, l_573, a_574, _v575) -- stdlib.ml:355
_v576 = iter_560(l_573)
return _v576
end
_m256 = function(i_467, match_468, _v469) -- stdlib.ml:283
return s_457
end
_m257 = function(i_470, match_471, _v472) -- stdlib.ml:282
_v473 = 2
_v474 = int_add(i_470, _v473)
_v475 = loop_459(_v474)
return _v475
end
_m282 = function(n_416, n_417) -- stdlib.ml:224
_v419 = invalid_arg_349(_v418)
return _v419
end
_m302 = function(greet_1018, x_1019, match_1020) _v1021 = {0, greet_1018}
_v1022 = 0
_v1023 = 0
_v1024 = _v1000[104]
-- std_exit.ml:18
_v1025 = _v1024(_v1023)
-- std_exit.ml:18
_v1026 = {0}
_v1027 = 0
return
end
-- stdlib.ml:486
_v783 = caml_ml_output_char(stdout_538, c_782)
-- stdlib.ml:486
return _v783
end
print_string_784 = function(s_785) -- stdlib.ml:487
local _m119
local _m192
local _m197
local _m207
local _m217
local _m222
local _m235
local _m256
local _m257
local _m282
local _m302
_m119 = function(param_893, _v894) -- stdlib.ml:567
_v895 = 0
_v896 = old_exit_884(_v895)
return _v896
end
_m192 = function(len_709, ofs_710, s_711, ic_712, _v713) -- stdlib.ml:435
_v715 = invalid_arg_349(_v714)
return _v715
end
_m197 = function(len_679, ofs_680, s_681, ic_682, _v683) -- stdlib.ml:422
_v685 = invalid_arg_349(_v684)
return _v685
end
_m207 = function(oc_644, _v645) -- stdlib.ml:395
local _ok, _res = pcall(function() _v649 = 0
-- stdlib.ml:395
return _v649
end)
if _ok then
exn_648 = _res
else
exn_648 = _res
-- stdlib.ml:395
_v650 = caml_ml_close_channel(oc_644)
-- stdlib.ml:395
end
end
_m217 = function(len_622, ofs_623, s_624, oc_625, _v626) -- stdlib.ml:378
_v628 = invalid_arg_349(_v627)
return _v628
end
_m222 = function(len_604, ofs_605, s_606, oc_607, _v608) -- stdlib.ml:373
_v610 = invalid_arg_349(_v609)
return _v610
end
_m235 = function(param_572, l_573, a_574, _v575) -- stdlib.ml:355
_v576 = iter_560(l_573)
return _v576
end
_m256 = function(i_467, match_468, _v469) -- stdlib.ml:283
return s_457
end
_m257 = function(i_470, match_471, _v472) -- stdlib.ml:282
_v473 = 2
_v474 = int_add(i_470, _v473)
_v475 = loop_459(_v474)
return _v475
end
_m282 = function(n_416, n_417) -- stdlib.ml:224
_v419 = invalid_arg_349(_v418)
return _v419
end
_m302 = function(greet_1018, x_1019, match_1020) _v1021 = {0, greet_1018}
_v1022 = 0
_v1023 = 0
_v1024 = _v1000[104]
-- std_exit.ml:18
_v1025 = _v1024(_v1023)
-- std_exit.ml:18
_v1026 = {0}
_v1027 = 0
return
end
-- stdlib.ml:487
_v786 = output_string_588(stdout_538, s_785)
return _v786
end
print_bytes_787 = function(s_788) -- stdlib.ml:488
local _m119
local _m192
local _m197
local _m207
local _m217
local _m222
local _m235
local _m256
local _m257
local _m282
local _m302
_m119 = function(param_893, _v894) -- stdlib.ml:567
_v895 = 0
_v896 = old_exit_884(_v895)
return _v896
end
_m192 = function(len_709, ofs_710, s_711, ic_712, _v713) -- stdlib.ml:435
_v715 = invalid_arg_349(_v714)
return _v715
end
_m197 = function(len_679, ofs_680, s_681, ic_682, _v683) -- stdlib.ml:422
_v685 = invalid_arg_349(_v684)
return _v685
end
_m207 = function(oc_644, _v645) -- stdlib.ml:395
local _ok, _res = pcall(function() _v649 = 0
-- stdlib.ml:395
return _v649
end)
if _ok then
exn_648 = _res
else
exn_648 = _res
-- stdlib.ml:395
_v650 = caml_ml_close_channel(oc_644)
-- stdlib.ml:395
end
end
_m217 = function(len_622, ofs_623, s_624, oc_625, _v626) -- stdlib.ml:378
_v628 = invalid_arg_349(_v627)
return _v628
end
_m222 = function(len_604, ofs_605, s_606, oc_607, _v608) -- stdlib.ml:373
_v610 = invalid_arg_349(_v609)
return _v610
end
_m235 = function(param_572, l_573, a_574, _v575) -- stdlib.ml:355
_v576 = iter_560(l_573)
return _v576
end
_m256 = function(i_467, match_468, _v469) -- stdlib.ml:283
return s_457
end
_m257 = function(i_470, match_471, _v472) -- stdlib.ml:282
_v473 = 2
_v474 = int_add(i_470, _v473)
_v475 = loop_459(_v474)
return _v475
end
_m282 = function(n_416, n_417) -- stdlib.ml:224
_v419 = invalid_arg_349(_v418)
return _v419
end
_m302 = function(greet_1018, x_1019, match_1020) _v1021 = {0, greet_1018}
_v1022 = 0
_v1023 = 0
_v1024 = _v1000[104]
-- std_exit.ml:18
_v1025 = _v1024(_v1023)
-- std_exit.ml:18
_v1026 = {0}
_v1027 = 0
return
end
-- stdlib.ml:488
_v789 = output_bytes_582(stdout_538, s_788)
return _v789
end
print_int_790 = function(i_791) -- stdlib.ml:489
local _m119
local _m192
local _m197
local _m207
local _m217
local _m222
local _m235
local _m256
local _m257
local _m282
local _m302
_m119 = function(param_893, _v894) -- stdlib.ml:567
_v895 = 0
_v896 = old_exit_884(_v895)
return _v896
end
_m192 = function(len_709, ofs_710, s_711, ic_712, _v713) -- stdlib.ml:435
_v715 = invalid_arg_349(_v714)
return _v715
end
_m197 = function(len_679, ofs_680, s_681, ic_682, _v683) -- stdlib.ml:422
_v685 = invalid_arg_349(_v684)
return _v685
end
_m207 = function(oc_644, _v645) -- stdlib.ml:395
local _ok, _res = pcall(function() _v649 = 0
-- stdlib.ml:395
return _v649
end)
if _ok then
exn_648 = _res
else
exn_648 = _res
-- stdlib.ml:395
_v650 = caml_ml_close_channel(oc_644)
-- stdlib.ml:395
end
end
_m217 = function(len_622, ofs_623, s_624, oc_625, _v626) -- stdlib.ml:378
_v628 = invalid_arg_349(_v627)
return _v628
end
_m222 = function(len_604, ofs_605, s_606, oc_607, _v608) -- stdlib.ml:373
_v610 = invalid_arg_349(_v609)
return _v610
end
_m235 = function(param_572, l_573, a_574, _v575) -- stdlib.ml:355
_v576 = iter_560(l_573)
return _v576
end
_m256 = function(i_467, match_468, _v469) -- stdlib.ml:283
return s_457
end
_m257 = function(i_470, match_471, _v472) -- stdlib.ml:282
_v473 = 2
_v474 = int_add(i_470, _v473)
_v475 = loop_459(_v474)
return _v475
end
_m282 = function(n_416, n_417) -- stdlib.ml:224
_v419 = invalid_arg_349(_v418)
return _v419
end
_m302 = function(greet_1018, x_1019, match_1020) _v1021 = {0, greet_1018}
_v1022 = 0
_v1023 = 0
_v1024 = _v1000[104]
-- std_exit.ml:18
_v1025 = _v1024(_v1023)
-- std_exit.ml:18
_v1026 = {0}
_v1027 = 0
return
end
-- stdlib.ml:489
_v792 = string_of_int_443(i_791)
-- stdlib.ml:489
_v793 = output_string_588(stdout_538, _v792)
return _v793
end
print_float_794 = function(f_795) -- stdlib.ml:490
local _m119
local _m192
local _m197
local _m207
local _m217
local _m222
local _m235
local _m256
local _m257
local _m282
local _m302
_m119 = function(param_893, _v894) -- stdlib.ml:567
_v895 = 0
_v896 = old_exit_884(_v895)
return _v896
end
_m192 = function(len_709, ofs_710, s_711, ic_712, _v713) -- stdlib.ml:435
_v715 = invalid_arg_349(_v714)
return _v715
end
_m197 = function(len_679, ofs_680, s_681, ic_682, _v683) -- stdlib.ml:422
_v685 = invalid_arg_349(_v684)
return _v685
end
_m207 = function(oc_644, _v645) -- stdlib.ml:395
local _ok, _res = pcall(function() _v649 = 0
-- stdlib.ml:395
return _v649
end)
if _ok then
exn_648 = _res
else
exn_648 = _res
-- stdlib.ml:395
_v650 = caml_ml_close_channel(oc_644)
-- stdlib.ml:395
end
end
_m217 = function(len_622, ofs_623, s_624, oc_625, _v626) -- stdlib.ml:378
_v628 = invalid_arg_349(_v627)
return _v628
end
_m222 = function(len_604, ofs_605, s_606, oc_607, _v608) -- stdlib.ml:373
_v610 = invalid_arg_349(_v609)
return _v610
end
_m235 = function(param_572, l_573, a_574, _v575) -- stdlib.ml:355
_v576 = iter_560(l_573)
return _v576
end
_m256 = function(i_467, match_468, _v469) -- stdlib.ml:283
return s_457
end
_m257 = function(i_470, match_471, _v472) -- stdlib.ml:282
_v473 = 2
_v474 = int_add(i_470, _v473)
_v475 = loop_459(_v474)
return _v475
end
_m282 = function(n_416, n_417) -- stdlib.ml:224
_v419 = invalid_arg_349(_v418)
return _v419
end
_m302 = function(greet_1018, x_1019, match_1020) _v1021 = {0, greet_1018}
_v1022 = 0
_v1023 = 0
_v1024 = _v1000[104]
-- std_exit.ml:18
_v1025 = _v1024(_v1023)
-- std_exit.ml:18
_v1026 = {0}
_v1027 = 0
return
end
-- stdlib.ml:490
_v796 = string_of_float_479(f_795)
-- stdlib.ml:490
_v797 = output_string_588(stdout_538, _v796)
return _v797
end
print_endline_798 = function(s_799) -- stdlib.ml:492
local _m119
local _m192
local _m197
local _m207
local _m217
local _m222
local _m235
local _m256
local _m257
local _m282
local _m302
_m119 = function(param_893, _v894) -- stdlib.ml:567
_v895 = 0
_v896 = old_exit_884(_v895)
return _v896
end
_m192 = function(len_709, ofs_710, s_711, ic_712, _v713) -- stdlib.ml:435
_v715 = invalid_arg_349(_v714)
return _v715
end
_m197 = function(len_679, ofs_680, s_681, ic_682, _v683) -- stdlib.ml:422
_v685 = invalid_arg_349(_v684)
return _v685
end
_m207 = function(oc_644, _v645) -- stdlib.ml:395
local _ok, _res = pcall(function() _v649 = 0
-- stdlib.ml:395
return _v649
end)
if _ok then
exn_648 = _res
else
exn_648 = _res
-- stdlib.ml:395
_v650 = caml_ml_close_channel(oc_644)
-- stdlib.ml:395
end
end
_m217 = function(len_622, ofs_623, s_624, oc_625, _v626) -- stdlib.ml:378
_v628 = invalid_arg_349(_v627)
return _v628
end
_m222 = function(len_604, ofs_605, s_606, oc_607, _v608) -- stdlib.ml:373
_v610 = invalid_arg_349(_v609)
return _v610
end
_m235 = function(param_572, l_573, a_574, _v575) -- stdlib.ml:355
_v576 = iter_560(l_573)
return _v576
end
_m256 = function(i_467, match_468, _v469) -- stdlib.ml:283
return s_457
end
_m257 = function(i_470, match_471, _v472) -- stdlib.ml:282
_v473 = 2
_v474 = int_add(i_470, _v473)
_v475 = loop_459(_v474)
return _v475
end
_m282 = function(n_416, n_417) -- stdlib.ml:224
_v419 = invalid_arg_349(_v418)
return _v419
end
_m302 = function(greet_1018, x_1019, match_1020) _v1021 = {0, greet_1018}
_v1022 = 0
_v1023 = 0
_v1024 = _v1000[104]
-- std_exit.ml:18
_v1025 = _v1024(_v1023)
-- std_exit.ml:18
_v1026 = {0}
_v1027 = 0
return
end
-- stdlib.ml:492
_v800 = output_string_588(stdout_538, s_799)
-- stdlib.ml:492
_v801 = 20
-- stdlib.ml:492
_v802 = caml_ml_output_char(stdout_538, _v801)
-- stdlib.ml:492
_v803 = caml_ml_flush(stdout_538)
-- stdlib.ml:492
return _v803
end
print_newline_804 = function(param_805) -- stdlib.ml:493
local _m119
local _m192
local _m197
local _m207
local _m217
local _m222
local _m235
local _m256
local _m257
local _m282
local _m302
_m119 = function(param_893, _v894) -- stdlib.ml:567
_v895 = 0
_v896 = old_exit_884(_v895)
return _v896
end
_m192 = function(len_709, ofs_710, s_711, ic_712, _v713) -- stdlib.ml:435
_v715 = invalid_arg_349(_v714)
return _v715
end
_m197 = function(len_679, ofs_680, s_681, ic_682, _v683) -- stdlib.ml:422
_v685 = invalid_arg_349(_v684)
return _v685
end
_m207 = function(oc_644, _v645) -- stdlib.ml:395
local _ok, _res = pcall(function() _v649 = 0
-- stdlib.ml:395
return _v649
end)
if _ok then
exn_648 = _res
else
exn_648 = _res
-- stdlib.ml:395
_v650 = caml_ml_close_channel(oc_644)
-- stdlib.ml:395
end
end
_m217 = function(len_622, ofs_623, s_624, oc_625, _v626) -- stdlib.ml:378
_v628 = invalid_arg_349(_v627)
return _v628
end
_m222 = function(len_604, ofs_605, s_606, oc_607, _v608) -- stdlib.ml:373
_v610 = invalid_arg_349(_v609)
return _v610
end
_m235 = function(param_572, l_573, a_574, _v575) -- stdlib.ml:355
_v576 = iter_560(l_573)
return _v576
end
_m256 = function(i_467, match_468, _v469) -- stdlib.ml:283
return s_457
end
_m257 = function(i_470, match_471, _v472) -- stdlib.ml:282
_v473 = 2
_v474 = int_add(i_470, _v473)
_v475 = loop_459(_v474)
return _v475
end
_m282 = function(n_416, n_417) -- stdlib.ml:224
_v419 = invalid_arg_349(_v418)
return _v419
end
_m302 = function(greet_1018, x_1019, match_1020) _v1021 = {0, greet_1018}
_v1022 = 0
_v1023 = 0
_v1024 = _v1000[104]
-- std_exit.ml:18
_v1025 = _v1024(_v1023)
-- std_exit.ml:18
_v1026 = {0}
_v1027 = 0
return
end
-- stdlib.ml:493
_v806 = 20
-- stdlib.ml:493
_v807 = caml_ml_output_char(stdout_538, _v806)
-- stdlib.ml:493
_v808 = caml_ml_flush(stdout_538)
-- stdlib.ml:493
return _v808
end
prerr_char_809 = function(c_810) -- stdlib.ml:497
local _m119
local _m192
local _m197
local _m207
local _m217
local _m222
local _m235
local _m256
local _m257
local _m282
local _m302
_m119 = function(param_893, _v894) -- stdlib.ml:567
_v895 = 0
_v896 = old_exit_884(_v895)
return _v896
end
_m192 = function(len_709, ofs_710, s_711, ic_712, _v713) -- stdlib.ml:435
_v715 = invalid_arg_349(_v714)
return _v715
end
_m197 = function(len_679, ofs_680, s_681, ic_682, _v683) -- stdlib.ml:422
_v685 = invalid_arg_349(_v684)
return _v685
end
_m207 = function(oc_644, _v645) -- stdlib.ml:395
local _ok, _res = pcall(function() _v649 = 0
-- stdlib.ml:395
return _v649
end)
if _ok then
exn_648 = _res
else
exn_648 = _res
-- stdlib.ml:395
_v650 = caml_ml_close_channel(oc_644)
-- stdlib.ml:395
end
end
_m217 = function(len_622, ofs_623, s_624, oc_625, _v626) -- stdlib.ml:378
_v628 = invalid_arg_349(_v627)
return _v628
end
_m222 = function(len_604, ofs_605, s_606, oc_607, _v608) -- stdlib.ml:373
_v610 = invalid_arg_349(_v609)
return _v610
end
_m235 = function(param_572, l_573, a_574, _v575) -- stdlib.ml:355
_v576 = iter_560(l_573)
return _v576
end
_m256 = function(i_467, match_468, _v469) -- stdlib.ml:283
return s_457
end
_m257 = function(i_470, match_471, _v472) -- stdlib.ml:282
_v473 = 2
_v474 = int_add(i_470, _v473)
_v475 = loop_459(_v474)
return _v475
end
_m282 = function(n_416, n_417) -- stdlib.ml:224
_v419 = invalid_arg_349(_v418)
return _v419
end
_m302 = function(greet_1018, x_1019, match_1020) _v1021 = {0, greet_1018}
_v1022 = 0
_v1023 = 0
_v1024 = _v1000[104]
-- std_exit.ml:18
_v1025 = _v1024(_v1023)
-- std_exit.ml:18
_v1026 = {0}
_v1027 = 0
return
end
-- stdlib.ml:497
_v811 = caml_ml_output_char(stderr_540, c_810)
-- stdlib.ml:497
return _v811
end
prerr_string_812 = function(s_813) -- stdlib.ml:498
local _m119
local _m192
local _m197
local _m207
local _m217
local _m222
local _m235
local _m256
local _m257
local _m282
local _m302
_m119 = function(param_893, _v894) -- stdlib.ml:567
_v895 = 0
_v896 = old_exit_884(_v895)
return _v896
end
_m192 = function(len_709, ofs_710, s_711, ic_712, _v713) -- stdlib.ml:435
_v715 = invalid_arg_349(_v714)
return _v715
end
_m197 = function(len_679, ofs_680, s_681, ic_682, _v683) -- stdlib.ml:422
_v685 = invalid_arg_349(_v684)
return _v685
end
_m207 = function(oc_644, _v645) -- stdlib.ml:395
local _ok, _res = pcall(function() _v649 = 0
-- stdlib.ml:395
return _v649
end)
if _ok then
exn_648 = _res
else
exn_648 = _res
-- stdlib.ml:395
_v650 = caml_ml_close_channel(oc_644)
-- stdlib.ml:395
end
end
_m217 = function(len_622, ofs_623, s_624, oc_625, _v626) -- stdlib.ml:378
_v628 = invalid_arg_349(_v627)
return _v628
end
_m222 = function(len_604, ofs_605, s_606, oc_607, _v608) -- stdlib.ml:373
_v610 = invalid_arg_349(_v609)
return _v610
end
_m235 = function(param_572, l_573, a_574, _v575) -- stdlib.ml:355
_v576 = iter_560(l_573)
return _v576
end
_m256 = function(i_467, match_468, _v469) -- stdlib.ml:283
return s_457
end
_m257 = function(i_470, match_471, _v472) -- stdlib.ml:282
_v473 = 2
_v474 = int_add(i_470, _v473)
_v475 = loop_459(_v474)
return _v475
end
_m282 = function(n_416, n_417) -- stdlib.ml:224
_v419 = invalid_arg_349(_v418)
return _v419
end
_m302 = function(greet_1018, x_1019, match_1020) _v1021 = {0, greet_1018}
_v1022 = 0
_v1023 = 0
_v1024 = _v1000[104]
-- std_exit.ml:18
_v1025 = _v1024(_v1023)
-- std_exit.ml:18
_v1026 = {0}
_v1027 = 0
return
end
-- stdlib.ml:498
_v814 = output_string_588(stderr_540, s_813)
return _v814
end
prerr_bytes_815 = function(s_816) -- stdlib.ml:499
local _m119
local _m192
local _m197
local _m207
local _m217
local _m222
local _m235
local _m256
local _m257
local _m282
local _m302
_m119 = function(param_893, _v894) -- stdlib.ml:567
_v895 = 0
_v896 = old_exit_884(_v895)
return _v896
end
_m192 = function(len_709, ofs_710, s_711, ic_712, _v713) -- stdlib.ml:435
_v715 = invalid_arg_349(_v714)
return _v715
end
_m197 = function(len_679, ofs_680, s_681, ic_682, _v683) -- stdlib.ml:422
_v685 = invalid_arg_349(_v684)
return _v685
end
_m207 = function(oc_644, _v645) -- stdlib.ml:395
local _ok, _res = pcall(function() _v649 = 0
-- stdlib.ml:395
return _v649
end)
if _ok then
exn_648 = _res
else
exn_648 = _res
-- stdlib.ml:395
_v650 = caml_ml_close_channel(oc_644)
-- stdlib.ml:395
end
end
_m217 = function(len_622, ofs_623, s_624, oc_625, _v626) -- stdlib.ml:378
_v628 = invalid_arg_349(_v627)
return _v628
end
_m222 = function(len_604, ofs_605, s_606, oc_607, _v608) -- stdlib.ml:373
_v610 = invalid_arg_349(_v609)
return _v610
end
_m235 = function(param_572, l_573, a_574, _v575) -- stdlib.ml:355
_v576 = iter_560(l_573)
return _v576
end
_m256 = function(i_467, match_468, _v469) -- stdlib.ml:283
return s_457
end
_m257 = function(i_470, match_471, _v472) -- stdlib.ml:282
_v473 = 2
_v474 = int_add(i_470, _v473)
_v475 = loop_459(_v474)
return _v475
end
_m282 = function(n_416, n_417) -- stdlib.ml:224
_v419 = invalid_arg_349(_v418)
return _v419
end
_m302 = function(greet_1018, x_1019, match_1020) _v1021 = {0, greet_1018}
_v1022 = 0
_v1023 = 0
_v1024 = _v1000[104]
-- std_exit.ml:18
_v1025 = _v1024(_v1023)
-- std_exit.ml:18
_v1026 = {0}
_v1027 = 0
return
end
-- stdlib.ml:499
_v817 = output_bytes_582(stderr_540, s_816)
return _v817
end
prerr_int_818 = function(i_819) -- stdlib.ml:500
local _m119
local _m192
local _m197
local _m207
local _m217
local _m222
local _m235
local _m256
local _m257
local _m282
local _m302
_m119 = function(param_893, _v894) -- stdlib.ml:567
_v895 = 0
_v896 = old_exit_884(_v895)
return _v896
end
_m192 = function(len_709, ofs_710, s_711, ic_712, _v713) -- stdlib.ml:435
_v715 = invalid_arg_349(_v714)
return _v715
end
_m197 = function(len_679, ofs_680, s_681, ic_682, _v683) -- stdlib.ml:422
_v685 = invalid_arg_349(_v684)
return _v685
end
_m207 = function(oc_644, _v645) -- stdlib.ml:395
local _ok, _res = pcall(function() _v649 = 0
-- stdlib.ml:395
return _v649
end)
if _ok then
exn_648 = _res
else
exn_648 = _res
-- stdlib.ml:395
_v650 = caml_ml_close_channel(oc_644)
-- stdlib.ml:395
end
end
_m217 = function(len_622, ofs_623, s_624, oc_625, _v626) -- stdlib.ml:378
_v628 = invalid_arg_349(_v627)
return _v628
end
_m222 = function(len_604, ofs_605, s_606, oc_607, _v608) -- stdlib.ml:373
_v610 = invalid_arg_349(_v609)
return _v610
end
_m235 = function(param_572, l_573, a_574, _v575) -- stdlib.ml:355
_v576 = iter_560(l_573)
return _v576
end
_m256 = function(i_467, match_468, _v469) -- stdlib.ml:283
return s_457
end
_m257 = function(i_470, match_471, _v472) -- stdlib.ml:282
_v473 = 2
_v474 = int_add(i_470, _v473)
_v475 = loop_459(_v474)
return _v475
end
_m282 = function(n_416, n_417) -- stdlib.ml:224
_v419 = invalid_arg_349(_v418)
return _v419
end
_m302 = function(greet_1018, x_1019, match_1020) _v1021 = {0, greet_1018}
_v1022 = 0
_v1023 = 0
_v1024 = _v1000[104]
-- std_exit.ml:18
_v1025 = _v1024(_v1023)
-- std_exit.ml:18
_v1026 = {0}
_v1027 = 0
return
end
-- stdlib.ml:500
_v820 = string_of_int_443(i_819)
-- stdlib.ml:500
_v821 = output_string_588(stderr_540, _v820)
return _v821
end
prerr_float_822 = function(f_823) -- stdlib.ml:501
local _m119
local _m192
local _m197
local _m207
local _m217
local _m222
local _m235
local _m256
local _m257
local _m282
local _m302
_m119 = function(param_893, _v894) -- stdlib.ml:567
_v895 = 0
_v896 = old_exit_884(_v895)
return _v896
end
_m192 = function(len_709, ofs_710, s_711, ic_712, _v713) -- stdlib.ml:435
_v715 = invalid_arg_349(_v714)
return _v715
end
_m197 = function(len_679, ofs_680, s_681, ic_682, _v683) -- stdlib.ml:422
_v685 = invalid_arg_349(_v684)
return _v685
end
_m207 = function(oc_644, _v645) -- stdlib.ml:395
local _ok, _res = pcall(function() _v649 = 0
-- stdlib.ml:395
return _v649
end)
if _ok then
exn_648 = _res
else
exn_648 = _res
-- stdlib.ml:395
_v650 = caml_ml_close_channel(oc_644)
-- stdlib.ml:395
end
end
_m217 = function(len_622, ofs_623, s_624, oc_625, _v626) -- stdlib.ml:378
_v628 = invalid_arg_349(_v627)
return _v628
end
_m222 = function(len_604, ofs_605, s_606, oc_607, _v608) -- stdlib.ml:373
_v610 = invalid_arg_349(_v609)
return _v610
end
_m235 = function(param_572, l_573, a_574, _v575) -- stdlib.ml:355
_v576 = iter_560(l_573)
return _v576
end
_m256 = function(i_467, match_468, _v469) -- stdlib.ml:283
return s_457
end
_m257 = function(i_470, match_471, _v472) -- stdlib.ml:282
_v473 = 2
_v474 = int_add(i_470, _v473)
_v475 = loop_459(_v474)
return _v475
end
_m282 = function(n_416, n_417) -- stdlib.ml:224
_v419 = invalid_arg_349(_v418)
return _v419
end
_m302 = function(greet_1018, x_1019, match_1020) _v1021 = {0, greet_1018}
_v1022 = 0
_v1023 = 0
_v1024 = _v1000[104]
-- std_exit.ml:18
_v1025 = _v1024(_v1023)
-- std_exit.ml:18
_v1026 = {0}
_v1027 = 0
return
end
-- stdlib.ml:501
_v824 = string_of_float_479(f_823)
-- stdlib.ml:501
_v825 = output_string_588(stderr_540, _v824)
return _v825
end
prerr_endline_826 = function(s_827) -- stdlib.ml:503
local _m119
local _m192
local _m197
local _m207
local _m217
local _m222
local _m235
local _m256
local _m257
local _m282
local _m302
_m119 = function(param_893, _v894) -- stdlib.ml:567
_v895 = 0
_v896 = old_exit_884(_v895)
return _v896
end
_m192 = function(len_709, ofs_710, s_711, ic_712, _v713) -- stdlib.ml:435
_v715 = invalid_arg_349(_v714)
return _v715
end
_m197 = function(len_679, ofs_680, s_681, ic_682, _v683) -- stdlib.ml:422
_v685 = invalid_arg_349(_v684)
return _v685
end
_m207 = function(oc_644, _v645) -- stdlib.ml:395
local _ok, _res = pcall(function() _v649 = 0
-- stdlib.ml:395
return _v649
end)
if _ok then
exn_648 = _res
else
exn_648 = _res
-- stdlib.ml:395
_v650 = caml_ml_close_channel(oc_644)
-- stdlib.ml:395
end
end
_m217 = function(len_622, ofs_623, s_624, oc_625, _v626) -- stdlib.ml:378
_v628 = invalid_arg_349(_v627)
return _v628
end
_m222 = function(len_604, ofs_605, s_606, oc_607, _v608) -- stdlib.ml:373
_v610 = invalid_arg_349(_v609)
return _v610
end
_m235 = function(param_572, l_573, a_574, _v575) -- stdlib.ml:355
_v576 = iter_560(l_573)
return _v576
end
_m256 = function(i_467, match_468, _v469) -- stdlib.ml:283
return s_457
end
_m257 = function(i_470, match_471, _v472) -- stdlib.ml:282
_v473 = 2
_v474 = int_add(i_470, _v473)
_v475 = loop_459(_v474)
return _v475
end
_m282 = function(n_416, n_417) -- stdlib.ml:224
_v419 = invalid_arg_349(_v418)
return _v419
end
_m302 = function(greet_1018, x_1019, match_1020) _v1021 = {0, greet_1018}
_v1022 = 0
_v1023 = 0
_v1024 = _v1000[104]
-- std_exit.ml:18
_v1025 = _v1024(_v1023)
-- std_exit.ml:18
_v1026 = {0}
_v1027 = 0
return
end
-- stdlib.ml:503
_v828 = output_string_588(stderr_540, s_827)
-- stdlib.ml:503
_v829 = 20
-- stdlib.ml:503
_v830 = caml_ml_output_char(stderr_540, _v829)
-- stdlib.ml:503
_v831 = caml_ml_flush(stderr_540)
-- stdlib.ml:503
return _v831
end
prerr_newline_832 = function(param_833) -- stdlib.ml:504
local _m119
local _m192
local _m197
local _m207
local _m217
local _m222
local _m235
local _m256
local _m257
local _m282
local _m302
_m119 = function(param_893, _v894) -- stdlib.ml:567
_v895 = 0
_v896 = old_exit_884(_v895)
return _v896
end
_m192 = function(len_709, ofs_710, s_711, ic_712, _v713) -- stdlib.ml:435
_v715 = invalid_arg_349(_v714)
return _v715
end
_m197 = function(len_679, ofs_680, s_681, ic_682, _v683) -- stdlib.ml:422
_v685 = invalid_arg_349(_v684)
return _v685
end
_m207 = function(oc_644, _v645) -- stdlib.ml:395
local _ok, _res = pcall(function() _v649 = 0
-- stdlib.ml:395
return _v649
end)
if _ok then
exn_648 = _res
else
exn_648 = _res
-- stdlib.ml:395
_v650 = caml_ml_close_channel(oc_644)
-- stdlib.ml:395
end
end
_m217 = function(len_622, ofs_623, s_624, oc_625, _v626) -- stdlib.ml:378
_v628 = invalid_arg_349(_v627)
return _v628
end
_m222 = function(len_604, ofs_605, s_606, oc_607, _v608) -- stdlib.ml:373
_v610 = invalid_arg_349(_v609)
return _v610
end
_m235 = function(param_572, l_573, a_574, _v575) -- stdlib.ml:355
_v576 = iter_560(l_573)
return _v576
end
_m256 = function(i_467, match_468, _v469) -- stdlib.ml:283
return s_457
end
_m257 = function(i_470, match_471, _v472) -- stdlib.ml:282
_v473 = 2
_v474 = int_add(i_470, _v473)
_v475 = loop_459(_v474)
return _v475
end
_m282 = function(n_416, n_417) -- stdlib.ml:224
_v419 = invalid_arg_349(_v418)
return _v419
end
_m302 = function(greet_1018, x_1019, match_1020) _v1021 = {0, greet_1018}
_v1022 = 0
_v1023 = 0
_v1024 = _v1000[104]
-- std_exit.ml:18
_v1025 = _v1024(_v1023)
-- std_exit.ml:18
_v1026 = {0}
_v1027 = 0
return
end
-- stdlib.ml:504
_v834 = 20
-- stdlib.ml:504
_v835 = caml_ml_output_char(stderr_540, _v834)
-- stdlib.ml:504
_v836 = caml_ml_flush(stderr_540)
-- stdlib.ml:504
return _v836
end
read_line_837 = function(param_838) -- stdlib.ml:508
local _m119
local _m192
local _m197
local _m207
local _m217
local _m222
local _m235
local _m256
local _m257
local _m282
local _m302
_m119 = function(param_893, _v894) -- stdlib.ml:567
_v895 = 0
_v896 = old_exit_884(_v895)
return _v896
end
_m192 = function(len_709, ofs_710, s_711, ic_712, _v713) -- stdlib.ml:435
_v715 = invalid_arg_349(_v714)
return _v715
end
_m197 = function(len_679, ofs_680, s_681, ic_682, _v683) -- stdlib.ml:422
_v685 = invalid_arg_349(_v684)
return _v685
end
_m207 = function(oc_644, _v645) -- stdlib.ml:395
local _ok, _res = pcall(function() _v649 = 0
-- stdlib.ml:395
return _v649
end)
if _ok then
exn_648 = _res
else
exn_648 = _res
-- stdlib.ml:395
_v650 = caml_ml_close_channel(oc_644)
-- stdlib.ml:395
end
end
_m217 = function(len_622, ofs_623, s_624, oc_625, _v626) -- stdlib.ml:378
_v628 = invalid_arg_349(_v627)
return _v628
end
_m222 = function(len_604, ofs_605, s_606, oc_607, _v608) -- stdlib.ml:373
_v610 = invalid_arg_349(_v609)
return _v610
end
_m235 = function(param_572, l_573, a_574, _v575) -- stdlib.ml:355
_v576 = iter_560(l_573)
return _v576
end
_m256 = function(i_467, match_468, _v469) -- stdlib.ml:283
return s_457
end
_m257 = function(i_470, match_471, _v472) -- stdlib.ml:282
_v473 = 2
_v474 = int_add(i_470, _v473)
_v475 = loop_459(_v474)
return _v475
end
_m282 = function(n_416, n_417) -- stdlib.ml:224
_v419 = invalid_arg_349(_v418)
return _v419
end
_m302 = function(greet_1018, x_1019, match_1020) _v1021 = {0, greet_1018}
_v1022 = 0
_v1023 = 0
_v1024 = _v1000[104]
-- std_exit.ml:18
_v1025 = _v1024(_v1023)
-- std_exit.ml:18
_v1026 = {0}
_v1027 = 0
return
end
-- stdlib.ml:508
_v839 = caml_ml_flush(stdout_538)
-- stdlib.ml:508
_v840 = input_line_724(stdin_536)
return _v840
end
read_int_841 = function(param_842) -- stdlib.ml:509
local _m119
local _m192
local _m197
local _m207
local _m217
local _m222
local _m235
local _m256
local _m257
local _m282
local _m302
_m119 = function(param_893, _v894) -- stdlib.ml:567
_v895 = 0
_v896 = old_exit_884(_v895)
return _v896
end
_m192 = function(len_709, ofs_710, s_711, ic_712, _v713) -- stdlib.ml:435
_v715 = invalid_arg_349(_v714)
return _v715
end
_m197 = function(len_679, ofs_680, s_681, ic_682, _v683) -- stdlib.ml:422
_v685 = invalid_arg_349(_v684)
return _v685
end
_m207 = function(oc_644, _v645) -- stdlib.ml:395
local _ok, _res = pcall(function() _v649 = 0
-- stdlib.ml:395
return _v649
end)
if _ok then
exn_648 = _res
else
exn_648 = _res
-- stdlib.ml:395
_v650 = caml_ml_close_channel(oc_644)
-- stdlib.ml:395
end
end
_m217 = function(len_622, ofs_623, s_624, oc_625, _v626) -- stdlib.ml:378
_v628 = invalid_arg_349(_v627)
return _v628
end
_m222 = function(len_604, ofs_605, s_606, oc_607, _v608) -- stdlib.ml:373
_v610 = invalid_arg_349(_v609)
return _v610
end
_m235 = function(param_572, l_573, a_574, _v575) -- stdlib.ml:355
_v576 = iter_560(l_573)
return _v576
end
_m256 = function(i_467, match_468, _v469) -- stdlib.ml:283
return s_457
end
_m257 = function(i_470, match_471, _v472) -- stdlib.ml:282
_v473 = 2
_v474 = int_add(i_470, _v473)
_v475 = loop_459(_v474)
return _v475
end
_m282 = function(n_416, n_417) -- stdlib.ml:224
_v419 = invalid_arg_349(_v418)
return _v419
end
_m302 = function(greet_1018, x_1019, match_1020) _v1021 = {0, greet_1018}
_v1022 = 0
_v1023 = 0
_v1024 = _v1000[104]
-- std_exit.ml:18
_v1025 = _v1024(_v1023)
-- std_exit.ml:18
_v1026 = {0}
_v1027 = 0
return
end
-- stdlib.ml:509
_v843 = 0
-- stdlib.ml:509
_v844 = read_line_837(_v843)
-- stdlib.ml:509
_v845 = caml_int_of_string(_v844)
-- stdlib.ml:509
return _v845
end
read_int_opt_846 = function(param_847) -- stdlib.ml:510
local _m119
local _m192
local _m197
local _m207
local _m217
local _m222
local _m235
local _m256
local _m257
local _m282
local _m302
_m119 = function(param_893, _v894) -- stdlib.ml:567
_v895 = 0
_v896 = old_exit_884(_v895)
return _v896
end
_m192 = function(len_709, ofs_710, s_711, ic_712, _v713) -- stdlib.ml:435
_v715 = invalid_arg_349(_v714)
return _v715
end
_m197 = function(len_679, ofs_680, s_681, ic_682, _v683) -- stdlib.ml:422
_v685 = invalid_arg_349(_v684)
return _v685
end
_m207 = function(oc_644, _v645) -- stdlib.ml:395
local _ok, _res = pcall(function() _v649 = 0
-- stdlib.ml:395
return _v649
end)
if _ok then
exn_648 = _res
else
exn_648 = _res
-- stdlib.ml:395
_v650 = caml_ml_close_channel(oc_644)
-- stdlib.ml:395
end
end
_m217 = function(len_622, ofs_623, s_624, oc_625, _v626) -- stdlib.ml:378
_v628 = invalid_arg_349(_v627)
return _v628
end
_m222 = function(len_604, ofs_605, s_606, oc_607, _v608) -- stdlib.ml:373
_v610 = invalid_arg_349(_v609)
return _v610
end
_m235 = function(param_572, l_573, a_574, _v575) -- stdlib.ml:355
_v576 = iter_560(l_573)
return _v576
end
_m256 = function(i_467, match_468, _v469) -- stdlib.ml:283
return s_457
end
_m257 = function(i_470, match_471, _v472) -- stdlib.ml:282
_v473 = 2
_v474 = int_add(i_470, _v473)
_v475 = loop_459(_v474)
return _v475
end
_m282 = function(n_416, n_417) -- stdlib.ml:224
_v419 = invalid_arg_349(_v418)
return _v419
end
_m302 = function(greet_1018, x_1019, match_1020) _v1021 = {0, greet_1018}
_v1022 = 0
_v1023 = 0
_v1024 = _v1000[104]
-- std_exit.ml:18
_v1025 = _v1024(_v1023)
-- std_exit.ml:18
_v1026 = {0}
_v1027 = 0
return
end
-- stdlib.ml:510
_v848 = 0
-- stdlib.ml:510
_v849 = read_line_837(_v848)
-- stdlib.ml:510
_v850 = int_of_string_opt_447(_v849)
return _v850
end
read_float_851 = function(param_852) -- stdlib.ml:511
local _m119
local _m192
local _m197
local _m207
local _m217
local _m222
local _m235
local _m256
local _m257
local _m282
local _m302
_m119 = function(param_893, _v894) -- stdlib.ml:567
_v895 = 0
_v896 = old_exit_884(_v895)
return _v896
end
_m192 = function(len_709, ofs_710, s_711, ic_712, _v713) -- stdlib.ml:435
_v715 = invalid_arg_349(_v714)
return _v715
end
_m197 = function(len_679, ofs_680, s_681, ic_682, _v683) -- stdlib.ml:422
_v685 = invalid_arg_349(_v684)
return _v685
end
_m207 = function(oc_644, _v645) -- stdlib.ml:395
local _ok, _res = pcall(function() _v649 = 0
-- stdlib.ml:395
return _v649
end)
if _ok then
exn_648 = _res
else
exn_648 = _res
-- stdlib.ml:395
_v650 = caml_ml_close_channel(oc_644)
-- stdlib.ml:395
end
end
_m217 = function(len_622, ofs_623, s_624, oc_625, _v626) -- stdlib.ml:378
_v628 = invalid_arg_349(_v627)
return _v628
end
_m222 = function(len_604, ofs_605, s_606, oc_607, _v608) -- stdlib.ml:373
_v610 = invalid_arg_349(_v609)
return _v610
end
_m235 = function(param_572, l_573, a_574, _v575) -- stdlib.ml:355
_v576 = iter_560(l_573)
return _v576
end
_m256 = function(i_467, match_468, _v469) -- stdlib.ml:283
return s_457
end
_m257 = function(i_470, match_471, _v472) -- stdlib.ml:282
_v473 = 2
_v474 = int_add(i_470, _v473)
_v475 = loop_459(_v474)
return _v475
end
_m282 = function(n_416, n_417) -- stdlib.ml:224
_v419 = invalid_arg_349(_v418)
return _v419
end
_m302 = function(greet_1018, x_1019, match_1020) _v1021 = {0, greet_1018}
_v1022 = 0
_v1023 = 0
_v1024 = _v1000[104]
-- std_exit.ml:18
_v1025 = _v1024(_v1023)
-- std_exit.ml:18
_v1026 = {0}
_v1027 = 0
return
end
-- stdlib.ml:511
_v853 = 0
-- stdlib.ml:511
_v854 = read_line_837(_v853)
-- stdlib.ml:511
_v855 = caml_float_of_string(_v854)
-- stdlib.ml:511
return _v855
end
read_float_opt_856 = function(param_857) -- stdlib.ml:512
local _m119
local _m192
local _m197
local _m207
local _m217
local _m222
local _m235
local _m256
local _m257
local _m282
local _m302
_m119 = function(param_893, _v894) -- stdlib.ml:567
_v895 = 0
_v896 = old_exit_884(_v895)
return _v896
end
_m192 = function(len_709, ofs_710, s_711, ic_712, _v713) -- stdlib.ml:435
_v715 = invalid_arg_349(_v714)
return _v715
end
_m197 = function(len_679, ofs_680, s_681, ic_682, _v683) -- stdlib.ml:422
_v685 = invalid_arg_349(_v684)
return _v685
end
_m207 = function(oc_644, _v645) -- stdlib.ml:395
local _ok, _res = pcall(function() _v649 = 0
-- stdlib.ml:395
return _v649
end)
if _ok then
exn_648 = _res
else
exn_648 = _res
-- stdlib.ml:395
_v650 = caml_ml_close_channel(oc_644)
-- stdlib.ml:395
end
end
_m217 = function(len_622, ofs_623, s_624, oc_625, _v626) -- stdlib.ml:378
_v628 = invalid_arg_349(_v627)
return _v628
end
_m222 = function(len_604, ofs_605, s_606, oc_607, _v608) -- stdlib.ml:373
_v610 = invalid_arg_349(_v609)
return _v610
end
_m235 = function(param_572, l_573, a_574, _v575) -- stdlib.ml:355
_v576 = iter_560(l_573)
return _v576
end
_m256 = function(i_467, match_468, _v469) -- stdlib.ml:283
return s_457
end
_m257 = function(i_470, match_471, _v472) -- stdlib.ml:282
_v473 = 2
_v474 = int_add(i_470, _v473)
_v475 = loop_459(_v474)
return _v475
end
_m282 = function(n_416, n_417) -- stdlib.ml:224
_v419 = invalid_arg_349(_v418)
return _v419
end
_m302 = function(greet_1018, x_1019, match_1020) _v1021 = {0, greet_1018}
_v1022 = 0
_v1023 = 0
_v1024 = _v1000[104]
-- std_exit.ml:18
_v1025 = _v1024(_v1023)
-- std_exit.ml:18
_v1026 = {0}
_v1027 = 0
return
end
-- stdlib.ml:512
_v858 = 0
-- stdlib.ml:512
_v859 = read_line_837(_v858)
-- stdlib.ml:512
_v860 = float_of_string_opt_484(_v859)
return _v860
end
LargeFile_861 = {0}
string_of_format_862 = function(param_863) -- stdlib.ml:538
local _m119
local _m192
local _m197
local _m207
local _m217
local _m222
local _m235
local _m256
local _m257
local _m282
local _m302
_m119 = function(param_893, _v894) -- stdlib.ml:567
_v895 = 0
_v896 = old_exit_884(_v895)
return _v896
end
_m192 = function(len_709, ofs_710, s_711, ic_712, _v713) -- stdlib.ml:435
_v715 = invalid_arg_349(_v714)
return _v715
end
_m197 = function(len_679, ofs_680, s_681, ic_682, _v683) -- stdlib.ml:422
_v685 = invalid_arg_349(_v684)
return _v685
end
_m207 = function(oc_644, _v645) -- stdlib.ml:395
local _ok, _res = pcall(function() _v649 = 0
-- stdlib.ml:395
return _v649
end)
if _ok then
exn_648 = _res
else
exn_648 = _res
-- stdlib.ml:395
_v650 = caml_ml_close_channel(oc_644)
-- stdlib.ml:395
end
end
_m217 = function(len_622, ofs_623, s_624, oc_625, _v626) -- stdlib.ml:378
_v628 = invalid_arg_349(_v627)
return _v628
end
_m222 = function(len_604, ofs_605, s_606, oc_607, _v608) -- stdlib.ml:373
_v610 = invalid_arg_349(_v609)
return _v610
end
_m235 = function(param_572, l_573, a_574, _v575) -- stdlib.ml:355
_v576 = iter_560(l_573)
return _v576
end
_m256 = function(i_467, match_468, _v469) -- stdlib.ml:283
return s_457
end
_m257 = function(i_470, match_471, _v472) -- stdlib.ml:282
_v473 = 2
_v474 = int_add(i_470, _v473)
_v475 = loop_459(_v474)
return _v475
end
_m282 = function(n_416, n_417) -- stdlib.ml:224
_v419 = invalid_arg_349(_v418)
return _v419
end
_m302 = function(greet_1018, x_1019, match_1020) _v1021 = {0, greet_1018}
_v1022 = 0
_v1023 = 0
_v1024 = _v1000[104]
-- std_exit.ml:18
_v1025 = _v1024(_v1023)
-- std_exit.ml:18
_v1026 = {0}
_v1027 = 0
return
end
-- stdlib.ml:538
str_864 = param_863[3]
-- stdlib.ml:538
return str_864
end
symbol_865 = function(_v867, param_866) -- stdlib.ml:546
local _m119
local _m192
local _m197
local _m207
local _m217
local _m222
local _m235
local _m256
local _m257
local _m282
local _m302
_m119 = function(param_893, _v894) -- stdlib.ml:567
_v895 = 0
_v896 = old_exit_884(_v895)
return _v896
end
_m192 = function(len_709, ofs_710, s_711, ic_712, _v713) -- stdlib.ml:435
_v715 = invalid_arg_349(_v714)
return _v715
end
_m197 = function(len_679, ofs_680, s_681, ic_682, _v683) -- stdlib.ml:422
_v685 = invalid_arg_349(_v684)
return _v685
end
_m207 = function(oc_644, _v645) -- stdlib.ml:395
local _ok, _res = pcall(function() _v649 = 0
-- stdlib.ml:395
return _v649
end)
if _ok then
exn_648 = _res
else
exn_648 = _res
-- stdlib.ml:395
_v650 = caml_ml_close_channel(oc_644)
-- stdlib.ml:395
end
end
_m217 = function(len_622, ofs_623, s_624, oc_625, _v626) -- stdlib.ml:378
_v628 = invalid_arg_349(_v627)
return _v628
end
_m222 = function(len_604, ofs_605, s_606, oc_607, _v608) -- stdlib.ml:373
_v610 = invalid_arg_349(_v609)
return _v610
end
_m235 = function(param_572, l_573, a_574, _v575) -- stdlib.ml:355
_v576 = iter_560(l_573)
return _v576
end
_m256 = function(i_467, match_468, _v469) -- stdlib.ml:283
return s_457
end
_m257 = function(i_470, match_471, _v472) -- stdlib.ml:282
_v473 = 2
_v474 = int_add(i_470, _v473)
_v475 = loop_459(_v474)
return _v475
end
_m282 = function(n_416, n_417) -- stdlib.ml:224
_v419 = invalid_arg_349(_v418)
return _v419
end
_m302 = function(greet_1018, x_1019, match_1020) _v1021 = {0, greet_1018}
_v1022 = 0
_v1023 = 0
_v1024 = _v1000[104]
-- std_exit.ml:18
_v1025 = _v1024(_v1023)
-- std_exit.ml:18
_v1026 = {0}
_v1027 = 0
return
end
-- stdlib.ml:544
str2_868 = param_866[3]
fmt2_869 = param_866[2]
str1_870 = _v867[3]
fmt1_871 = _v867[2]
-- stdlib.ml:546
_v873 = symbol_concat_399(_v872, str2_868)
-- stdlib.ml:546
_v874 = symbol_concat_399(str1_870, _v873)
-- stdlib.ml:546
_v875 = _v337[4]
-- stdlib.ml:545
_v876 = _v875(fmt1_871, fmt2_869)
-- stdlib.ml:545
_v877 = {0, _v876, _v874}
return _v877
end
exit_function_878 = {0, flush_all_558}
at_exit_879 = function(f_880) -- stdlib.ml:570
local _m119
local _m192
local _m197
local _m207
local _m217
local _m222
local _m235
local _m256
local _m257
local _m282
local _m302
_m119 = function(param_893, _v894) -- stdlib.ml:567
_v895 = 0
_v896 = old_exit_884(_v895)
return _v896
end
_m192 = function(len_709, ofs_710, s_711, ic_712, _v713) -- stdlib.ml:435
_v715 = invalid_arg_349(_v714)
return _v715
end
_m197 = function(len_679, ofs_680, s_681, ic_682, _v683) -- stdlib.ml:422
_v685 = invalid_arg_349(_v684)
return _v685
end
_m207 = function(oc_644, _v645) -- stdlib.ml:395
local _ok, _res = pcall(function() _v649 = 0
-- stdlib.ml:395
return _v649
end)
if _ok then
exn_648 = _res
else
exn_648 = _res
-- stdlib.ml:395
_v650 = caml_ml_close_channel(oc_644)
-- stdlib.ml:395
end
end
_m217 = function(len_622, ofs_623, s_624, oc_625, _v626) -- stdlib.ml:378
_v628 = invalid_arg_349(_v627)
return _v628
end
_m222 = function(len_604, ofs_605, s_606, oc_607, _v608) -- stdlib.ml:373
_v610 = invalid_arg_349(_v609)
return _v610
end
_m235 = function(param_572, l_573, a_574, _v575) -- stdlib.ml:355
_v576 = iter_560(l_573)
return _v576
end
_m256 = function(i_467, match_468, _v469) -- stdlib.ml:283
return s_457
end
_m257 = function(i_470, match_471, _v472) -- stdlib.ml:282
_v473 = 2
_v474 = int_add(i_470, _v473)
_v475 = loop_459(_v474)
return _v475
end
_m282 = function(n_416, n_417) -- stdlib.ml:224
_v419 = invalid_arg_349(_v418)
return _v419
end
_m302 = function(greet_1018, x_1019, match_1020) _v1021 = {0, greet_1018}
_v1022 = 0
_v1023 = 0
_v1024 = _v1000[104]
-- std_exit.ml:18
_v1025 = _v1024(_v1023)
-- std_exit.ml:18
_v1026 = {0}
_v1027 = 0
return
end
-- stdlib.ml:563
_v881 = 2
f_yet_to_run_882 = {0, _v881}
_v883 = 0
-- stdlib.ml:564
old_exit_884 = caml_atomic_load_field(exit_function_878, _v883)
-- stdlib.ml:565
new_exit_885 = function(param_886) -- stdlib.ml:567
local _m119
local _m192
local _m197
local _m207
local _m217
local _m222
local _m235
local _m256
local _m257
local _m282
local _m302
_m119 = function(param_893, _v894) -- stdlib.ml:567
_v895 = 0
_v896 = old_exit_884(_v895)
return _v896
end
_m192 = function(len_709, ofs_710, s_711, ic_712, _v713) -- stdlib.ml:435
_v715 = invalid_arg_349(_v714)
return _v715
end
_m197 = function(len_679, ofs_680, s_681, ic_682, _v683) -- stdlib.ml:422
_v685 = invalid_arg_349(_v684)
return _v685
end
_m207 = function(oc_644, _v645) -- stdlib.ml:395
local _ok, _res = pcall(function() _v649 = 0
-- stdlib.ml:395
return _v649
end)
if _ok then
exn_648 = _res
else
exn_648 = _res
-- stdlib.ml:395
_v650 = caml_ml_close_channel(oc_644)
-- stdlib.ml:395
end
end
_m217 = function(len_622, ofs_623, s_624, oc_625, _v626) -- stdlib.ml:378
_v628 = invalid_arg_349(_v627)
return _v628
end
_m222 = function(len_604, ofs_605, s_606, oc_607, _v608) -- stdlib.ml:373
_v610 = invalid_arg_349(_v609)
return _v610
end
_m235 = function(param_572, l_573, a_574, _v575) -- stdlib.ml:355
_v576 = iter_560(l_573)
return _v576
end
_m256 = function(i_467, match_468, _v469) -- stdlib.ml:283
return s_457
end
_m257 = function(i_470, match_471, _v472) -- stdlib.ml:282
_v473 = 2
_v474 = int_add(i_470, _v473)
_v475 = loop_459(_v474)
return _v475
end
_m282 = function(n_416, n_417) -- stdlib.ml:224
_v419 = invalid_arg_349(_v418)
return _v419
end
_m302 = function(greet_1018, x_1019, match_1020) _v1021 = {0, greet_1018}
_v1022 = 0
_v1023 = 0
_v1024 = _v1000[104]
-- std_exit.ml:18
_v1025 = _v1024(_v1023)
-- std_exit.ml:18
_v1026 = {0}
_v1027 = 0
return
end
-- stdlib.ml:566
_v887 = 0
_v888 = 2
_v889 = 0
_v890 = caml_atomic_cas_field(f_yet_to_run_882, _v889, _v888, _v887)
if _v890 then
-- stdlib.ml:566
_v891 = 0
-- stdlib.ml:566
_v892 = f_880(_v891)
-- stdlib.ml:567
return _m119(param_886, _v892)
else
return _m119(param_886, _v890)
end
end
-- stdlib.ml:569
_v897 = 0
success_898 = caml_atomic_cas_field(exit_function_878, _v897, old_exit_884, new_exit_885)
-- stdlib.ml:570
_v899 = not success_898
if _v899 then
-- stdlib.ml:570
_v900 = at_exit_879(f_880)
return _v900
else
return _v899
end
end
_v901 = function(param_902) -- stdlib.ml:572
local _m119
local _m192
local _m197
local _m207
local _m217
local _m222
local _m235
local _m256
local _m257
local _m282
local _m302
_m119 = function(param_893, _v894) -- stdlib.ml:567
_v895 = 0
_v896 = old_exit_884(_v895)
return _v896
end
_m192 = function(len_709, ofs_710, s_711, ic_712, _v713) -- stdlib.ml:435
_v715 = invalid_arg_349(_v714)
return _v715
end
_m197 = function(len_679, ofs_680, s_681, ic_682, _v683) -- stdlib.ml:422
_v685 = invalid_arg_349(_v684)
return _v685
end
_m207 = function(oc_644, _v645) -- stdlib.ml:395
local _ok, _res = pcall(function() _v649 = 0
-- stdlib.ml:395
return _v649
end)
if _ok then
exn_648 = _res
else
exn_648 = _res
-- stdlib.ml:395
_v650 = caml_ml_close_channel(oc_644)
-- stdlib.ml:395
end
end
_m217 = function(len_622, ofs_623, s_624, oc_625, _v626) -- stdlib.ml:378
_v628 = invalid_arg_349(_v627)
return _v628
end
_m222 = function(len_604, ofs_605, s_606, oc_607, _v608) -- stdlib.ml:373
_v610 = invalid_arg_349(_v609)
return _v610
end
_m235 = function(param_572, l_573, a_574, _v575) -- stdlib.ml:355
_v576 = iter_560(l_573)
return _v576
end
_m256 = function(i_467, match_468, _v469) -- stdlib.ml:283
return s_457
end
_m257 = function(i_470, match_471, _v472) -- stdlib.ml:282
_v473 = 2
_v474 = int_add(i_470, _v473)
_v475 = loop_459(_v474)
return _v475
end
_m282 = function(n_416, n_417) -- stdlib.ml:224
_v419 = invalid_arg_349(_v418)
return _v419
end
_m302 = function(greet_1018, x_1019, match_1020) _v1021 = {0, greet_1018}
_v1022 = 0
_v1023 = 0
_v1024 = _v1000[104]
-- std_exit.ml:18
_v1025 = _v1024(_v1023)
-- std_exit.ml:18
_v1026 = {0}
_v1027 = 0
return
end
-- stdlib.ml:572
_v903 = 0
return _v903
end
do_domain_local_at_exit_904 = {0, _v901}
do_at_exit_905 = function(param_906) -- stdlib.ml:576
local _m119
local _m192
local _m197
local _m207
local _m217
local _m222
local _m235
local _m256
local _m257
local _m282
local _m302
_m119 = function(param_893, _v894) -- stdlib.ml:567
_v895 = 0
_v896 = old_exit_884(_v895)
return _v896
end
_m192 = function(len_709, ofs_710, s_711, ic_712, _v713) -- stdlib.ml:435
_v715 = invalid_arg_349(_v714)
return _v715
end
_m197 = function(len_679, ofs_680, s_681, ic_682, _v683) -- stdlib.ml:422
_v685 = invalid_arg_349(_v684)
return _v685
end
_m207 = function(oc_644, _v645) -- stdlib.ml:395
local _ok, _res = pcall(function() _v649 = 0
-- stdlib.ml:395
return _v649
end)
if _ok then
exn_648 = _res
else
exn_648 = _res
-- stdlib.ml:395
_v650 = caml_ml_close_channel(oc_644)
-- stdlib.ml:395
end
end
_m217 = function(len_622, ofs_623, s_624, oc_625, _v626) -- stdlib.ml:378
_v628 = invalid_arg_349(_v627)
return _v628
end
_m222 = function(len_604, ofs_605, s_606, oc_607, _v608) -- stdlib.ml:373
_v610 = invalid_arg_349(_v609)
return _v610
end
_m235 = function(param_572, l_573, a_574, _v575) -- stdlib.ml:355
_v576 = iter_560(l_573)
return _v576
end
_m256 = function(i_467, match_468, _v469) -- stdlib.ml:283
return s_457
end
_m257 = function(i_470, match_471, _v472) -- stdlib.ml:282
_v473 = 2
_v474 = int_add(i_470, _v473)
_v475 = loop_459(_v474)
return _v475
end
_m282 = function(n_416, n_417) -- stdlib.ml:224
_v419 = invalid_arg_349(_v418)
return _v419
end
_m302 = function(greet_1018, x_1019, match_1020) _v1021 = {0, greet_1018}
_v1022 = 0
_v1023 = 0
_v1024 = _v1000[104]
-- std_exit.ml:18
_v1025 = _v1024(_v1023)
-- std_exit.ml:18
_v1026 = {0}
_v1027 = 0
return
end
-- stdlib.ml:575
_v907 = 0
_v908 = do_domain_local_at_exit_904[2]
-- stdlib.ml:575
_v909 = _v908(_v907)
-- stdlib.ml:575
_v910 = 0
_v911 = 0
_v912 = caml_atomic_load_field(exit_function_878, _v911)
_v913 = _v912(_v910)
return _v913
end
exit_914 = function(retcode_915) -- stdlib.ml:580
local _m119
local _m192
local _m197
local _m207
local _m217
local _m222
local _m235
local _m256
local _m257
local _m282
local _m302
_m119 = function(param_893, _v894) -- stdlib.ml:567
_v895 = 0
_v896 = old_exit_884(_v895)
return _v896
end
_m192 = function(len_709, ofs_710, s_711, ic_712, _v713) -- stdlib.ml:435
_v715 = invalid_arg_349(_v714)
return _v715
end
_m197 = function(len_679, ofs_680, s_681, ic_682, _v683) -- stdlib.ml:422
_v685 = invalid_arg_349(_v684)
return _v685
end
_m207 = function(oc_644, _v645) -- stdlib.ml:395
local _ok, _res = pcall(function() _v649 = 0
-- stdlib.ml:395
return _v649
end)
if _ok then
exn_648 = _res
else
exn_648 = _res
-- stdlib.ml:395
_v650 = caml_ml_close_channel(oc_644)
-- stdlib.ml:395
end
end
_m217 = function(len_622, ofs_623, s_624, oc_625, _v626) -- stdlib.ml:378
_v628 = invalid_arg_349(_v627)
return _v628
end
_m222 = function(len_604, ofs_605, s_606, oc_607, _v608) -- stdlib.ml:373
_v610 = invalid_arg_349(_v609)
return _v610
end
_m235 = function(param_572, l_573, a_574, _v575) -- stdlib.ml:355
_v576 = iter_560(l_573)
return _v576
end
_m256 = function(i_467, match_468, _v469) -- stdlib.ml:283
return s_457
end
_m257 = function(i_470, match_471, _v472) -- stdlib.ml:282
_v473 = 2
_v474 = int_add(i_470, _v473)
_v475 = loop_459(_v474)
return _v475
end
_m282 = function(n_416, n_417) -- stdlib.ml:224
_v419 = invalid_arg_349(_v418)
return _v419
end
_m302 = function(greet_1018, x_1019, match_1020) _v1021 = {0, greet_1018}
_v1022 = 0
_v1023 = 0
_v1024 = _v1000[104]
-- std_exit.ml:18
_v1025 = _v1024(_v1023)
-- std_exit.ml:18
_v1026 = {0}
_v1027 = 0
return
end
-- stdlib.ml:579
_v916 = 0
-- stdlib.ml:579
_v917 = do_at_exit_905(_v916)
-- stdlib.ml:580
_v918 = caml_sys_exit(retcode_915)
-- stdlib.ml:580
return _v918
end
-- stdlib.ml:582
_v920 = caml_register_named_value(_v919, do_at_exit_905)
-- stdlib.ml:582
_v921 = function(_v922) local _m119
local _m192
local _m197
local _m207
local _m217
local _m222
local _m235
local _m256
local _m257
local _m282
local _m302
_m119 = function(param_893, _v894) -- stdlib.ml:567
_v895 = 0
_v896 = old_exit_884(_v895)
return _v896
end
_m192 = function(len_709, ofs_710, s_711, ic_712, _v713) -- stdlib.ml:435
_v715 = invalid_arg_349(_v714)
return _v715
end
_m197 = function(len_679, ofs_680, s_681, ic_682, _v683) -- stdlib.ml:422
_v685 = invalid_arg_349(_v684)
return _v685
end
_m207 = function(oc_644, _v645) -- stdlib.ml:395
local _ok, _res = pcall(function() _v649 = 0
-- stdlib.ml:395
return _v649
end)
if _ok then
exn_648 = _res
else
exn_648 = _res
-- stdlib.ml:395
_v650 = caml_ml_close_channel(oc_644)
-- stdlib.ml:395
end
end
_m217 = function(len_622, ofs_623, s_624, oc_625, _v626) -- stdlib.ml:378
_v628 = invalid_arg_349(_v627)
return _v628
end
_m222 = function(len_604, ofs_605, s_606, oc_607, _v608) -- stdlib.ml:373
_v610 = invalid_arg_349(_v609)
return _v610
end
_m235 = function(param_572, l_573, a_574, _v575) -- stdlib.ml:355
_v576 = iter_560(l_573)
return _v576
end
_m256 = function(i_467, match_468, _v469) -- stdlib.ml:283
return s_457
end
_m257 = function(i_470, match_471, _v472) -- stdlib.ml:282
_v473 = 2
_v474 = int_add(i_470, _v473)
_v475 = loop_459(_v474)
return _v475
end
_m282 = function(n_416, n_417) -- stdlib.ml:224
_v419 = invalid_arg_349(_v418)
return _v419
end
_m302 = function(greet_1018, x_1019, match_1020) _v1021 = {0, greet_1018}
_v1022 = 0
_v1023 = 0
_v1024 = _v1000[104]
-- std_exit.ml:18
_v1025 = _v1024(_v1023)
-- std_exit.ml:18
_v1026 = {0}
_v1027 = 0
return
end
_v923 = caml_ml_channel_size_64(_v922)
return _v923
end
_v924 = function(_v925) local _m119
local _m192
local _m197
local _m207
local _m217
local _m222
local _m235
local _m256
local _m257
local _m282
local _m302
_m119 = function(param_893, _v894) -- stdlib.ml:567
_v895 = 0
_v896 = old_exit_884(_v895)
return _v896
end
_m192 = function(len_709, ofs_710, s_711, ic_712, _v713) -- stdlib.ml:435
_v715 = invalid_arg_349(_v714)
return _v715
end
_m197 = function(len_679, ofs_680, s_681, ic_682, _v683) -- stdlib.ml:422
_v685 = invalid_arg_349(_v684)
return _v685
end
_m207 = function(oc_644, _v645) -- stdlib.ml:395
local _ok, _res = pcall(function() _v649 = 0
-- stdlib.ml:395
return _v649
end)
if _ok then
exn_648 = _res
else
exn_648 = _res
-- stdlib.ml:395
_v650 = caml_ml_close_channel(oc_644)
-- stdlib.ml:395
end
end
_m217 = function(len_622, ofs_623, s_624, oc_625, _v626) -- stdlib.ml:378
_v628 = invalid_arg_349(_v627)
return _v628
end
_m222 = function(len_604, ofs_605, s_606, oc_607, _v608) -- stdlib.ml:373
_v610 = invalid_arg_349(_v609)
return _v610
end
_m235 = function(param_572, l_573, a_574, _v575) -- stdlib.ml:355
_v576 = iter_560(l_573)
return _v576
end
_m256 = function(i_467, match_468, _v469) -- stdlib.ml:283
return s_457
end
_m257 = function(i_470, match_471, _v472) -- stdlib.ml:282
_v473 = 2
_v474 = int_add(i_470, _v473)
_v475 = loop_459(_v474)
return _v475
end
_m282 = function(n_416, n_417) -- stdlib.ml:224
_v419 = invalid_arg_349(_v418)
return _v419
end
_m302 = function(greet_1018, x_1019, match_1020) _v1021 = {0, greet_1018}
_v1022 = 0
_v1023 = 0
_v1024 = _v1000[104]
-- std_exit.ml:18
_v1025 = _v1024(_v1023)
-- std_exit.ml:18
_v1026 = {0}
_v1027 = 0
return
end
_v926 = caml_ml_pos_in_64(_v925)
return _v926
end
_v927 = function(_v929, _v928) local _m119
local _m192
local _m197
local _m207
local _m217
local _m222
local _m235
local _m256
local _m257
local _m282
local _m302
_m119 = function(param_893, _v894) -- stdlib.ml:567
_v895 = 0
_v896 = old_exit_884(_v895)
return _v896
end
_m192 = function(len_709, ofs_710, s_711, ic_712, _v713) -- stdlib.ml:435
_v715 = invalid_arg_349(_v714)
return _v715
end
_m197 = function(len_679, ofs_680, s_681, ic_682, _v683) -- stdlib.ml:422
_v685 = invalid_arg_349(_v684)
return _v685
end
_m207 = function(oc_644, _v645) -- stdlib.ml:395
local _ok, _res = pcall(function() _v649 = 0
-- stdlib.ml:395
return _v649
end)
if _ok then
exn_648 = _res
else
exn_648 = _res
-- stdlib.ml:395
_v650 = caml_ml_close_channel(oc_644)
-- stdlib.ml:395
end
end
_m217 = function(len_622, ofs_623, s_624, oc_625, _v626) -- stdlib.ml:378
_v628 = invalid_arg_349(_v627)
return _v628
end
_m222 = function(len_604, ofs_605, s_606, oc_607, _v608) -- stdlib.ml:373
_v610 = invalid_arg_349(_v609)
return _v610
end
_m235 = function(param_572, l_573, a_574, _v575) -- stdlib.ml:355
_v576 = iter_560(l_573)
return _v576
end
_m256 = function(i_467, match_468, _v469) -- stdlib.ml:283
return s_457
end
_m257 = function(i_470, match_471, _v472) -- stdlib.ml:282
_v473 = 2
_v474 = int_add(i_470, _v473)
_v475 = loop_459(_v474)
return _v475
end
_m282 = function(n_416, n_417) -- stdlib.ml:224
_v419 = invalid_arg_349(_v418)
return _v419
end
_m302 = function(greet_1018, x_1019, match_1020) _v1021 = {0, greet_1018}
_v1022 = 0
_v1023 = 0
_v1024 = _v1000[104]
-- std_exit.ml:18
_v1025 = _v1024(_v1023)
-- std_exit.ml:18
_v1026 = {0}
_v1027 = 0
return
end
_v930 = caml_ml_seek_in_64(_v929, _v928)
return _v930
end
_v931 = function(_v932) local _m119
local _m192
local _m197
local _m207
local _m217
local _m222
local _m235
local _m256
local _m257
local _m282
local _m302
_m119 = function(param_893, _v894) -- stdlib.ml:567
_v895 = 0
_v896 = old_exit_884(_v895)
return _v896
end
_m192 = function(len_709, ofs_710, s_711, ic_712, _v713) -- stdlib.ml:435
_v715 = invalid_arg_349(_v714)
return _v715
end
_m197 = function(len_679, ofs_680, s_681, ic_682, _v683) -- stdlib.ml:422
_v685 = invalid_arg_349(_v684)
return _v685
end
_m207 = function(oc_644, _v645) -- stdlib.ml:395
local _ok, _res = pcall(function() _v649 = 0
-- stdlib.ml:395
return _v649
end)
if _ok then
exn_648 = _res
else
exn_648 = _res
-- stdlib.ml:395
_v650 = caml_ml_close_channel(oc_644)
-- stdlib.ml:395
end
end
_m217 = function(len_622, ofs_623, s_624, oc_625, _v626) -- stdlib.ml:378
_v628 = invalid_arg_349(_v627)
return _v628
end
_m222 = function(len_604, ofs_605, s_606, oc_607, _v608) -- stdlib.ml:373
_v610 = invalid_arg_349(_v609)
return _v610
end
_m235 = function(param_572, l_573, a_574, _v575) -- stdlib.ml:355
_v576 = iter_560(l_573)
return _v576
end
_m256 = function(i_467, match_468, _v469) -- stdlib.ml:283
return s_457
end
_m257 = function(i_470, match_471, _v472) -- stdlib.ml:282
_v473 = 2
_v474 = int_add(i_470, _v473)
_v475 = loop_459(_v474)
return _v475
end
_m282 = function(n_416, n_417) -- stdlib.ml:224
_v419 = invalid_arg_349(_v418)
return _v419
end
_m302 = function(greet_1018, x_1019, match_1020) _v1021 = {0, greet_1018}
_v1022 = 0
_v1023 = 0
_v1024 = _v1000[104]
-- std_exit.ml:18
_v1025 = _v1024(_v1023)
-- std_exit.ml:18
_v1026 = {0}
_v1027 = 0
return
end
_v933 = caml_ml_channel_size_64(_v932)
return _v933
end
_v934 = function(_v935) local _m119
local _m192
local _m197
local _m207
local _m217
local _m222
local _m235
local _m256
local _m257
local _m282
local _m302
_m119 = function(param_893, _v894) -- stdlib.ml:567
_v895 = 0
_v896 = old_exit_884(_v895)
return _v896
end
_m192 = function(len_709, ofs_710, s_711, ic_712, _v713) -- stdlib.ml:435
_v715 = invalid_arg_349(_v714)
return _v715
end
_m197 = function(len_679, ofs_680, s_681, ic_682, _v683) -- stdlib.ml:422
_v685 = invalid_arg_349(_v684)
return _v685
end
_m207 = function(oc_644, _v645) -- stdlib.ml:395
local _ok, _res = pcall(function() _v649 = 0
-- stdlib.ml:395
return _v649
end)
if _ok then
exn_648 = _res
else
exn_648 = _res
-- stdlib.ml:395
_v650 = caml_ml_close_channel(oc_644)
-- stdlib.ml:395
end
end
_m217 = function(len_622, ofs_623, s_624, oc_625, _v626) -- stdlib.ml:378
_v628 = invalid_arg_349(_v627)
return _v628
end
_m222 = function(len_604, ofs_605, s_606, oc_607, _v608) -- stdlib.ml:373
_v610 = invalid_arg_349(_v609)
return _v610
end
_m235 = function(param_572, l_573, a_574, _v575) -- stdlib.ml:355
_v576 = iter_560(l_573)
return _v576
end
_m256 = function(i_467, match_468, _v469) -- stdlib.ml:283
return s_457
end
_m257 = function(i_470, match_471, _v472) -- stdlib.ml:282
_v473 = 2
_v474 = int_add(i_470, _v473)
_v475 = loop_459(_v474)
return _v475
end
_m282 = function(n_416, n_417) -- stdlib.ml:224
_v419 = invalid_arg_349(_v418)
return _v419
end
_m302 = function(greet_1018, x_1019, match_1020) _v1021 = {0, greet_1018}
_v1022 = 0
_v1023 = 0
_v1024 = _v1000[104]
-- std_exit.ml:18
_v1025 = _v1024(_v1023)
-- std_exit.ml:18
_v1026 = {0}
_v1027 = 0
return
end
_v936 = caml_ml_pos_out_64(_v935)
return _v936
end
_v937 = function(_v939, _v938) local _m119
local _m192
local _m197
local _m207
local _m217
local _m222
local _m235
local _m256
local _m257
local _m282
local _m302
_m119 = function(param_893, _v894) -- stdlib.ml:567
_v895 = 0
_v896 = old_exit_884(_v895)
return _v896
end
_m192 = function(len_709, ofs_710, s_711, ic_712, _v713) -- stdlib.ml:435
_v715 = invalid_arg_349(_v714)
return _v715
end
_m197 = function(len_679, ofs_680, s_681, ic_682, _v683) -- stdlib.ml:422
_v685 = invalid_arg_349(_v684)
return _v685
end
_m207 = function(oc_644, _v645) -- stdlib.ml:395
local _ok, _res = pcall(function() _v649 = 0
-- stdlib.ml:395
return _v649
end)
if _ok then
exn_648 = _res
else
exn_648 = _res
-- stdlib.ml:395
_v650 = caml_ml_close_channel(oc_644)
-- stdlib.ml:395
end
end
_m217 = function(len_622, ofs_623, s_624, oc_625, _v626) -- stdlib.ml:378
_v628 = invalid_arg_349(_v627)
return _v628
end
_m222 = function(len_604, ofs_605, s_606, oc_607, _v608) -- stdlib.ml:373
_v610 = invalid_arg_349(_v609)
return _v610
end
_m235 = function(param_572, l_573, a_574, _v575) -- stdlib.ml:355
_v576 = iter_560(l_573)
return _v576
end
_m256 = function(i_467, match_468, _v469) -- stdlib.ml:283
return s_457
end
_m257 = function(i_470, match_471, _v472) -- stdlib.ml:282
_v473 = 2
_v474 = int_add(i_470, _v473)
_v475 = loop_459(_v474)
return _v475
end
_m282 = function(n_416, n_417) -- stdlib.ml:224
_v419 = invalid_arg_349(_v418)
return _v419
end
_m302 = function(greet_1018, x_1019, match_1020) _v1021 = {0, greet_1018}
_v1022 = 0
_v1023 = 0
_v1024 = _v1000[104]
-- std_exit.ml:18
_v1025 = _v1024(_v1023)
-- std_exit.ml:18
_v1026 = {0}
_v1027 = 0
return
end
_v940 = caml_ml_seek_out_64(_v939, _v938)
return _v940
end
_v941 = {0, _v937, _v934, _v931, _v927, _v924, _v921}
_v942 = function(_v944, _v943) local _m119
local _m192
local _m197
local _m207
local _m217
local _m222
local _m235
local _m256
local _m257
local _m282
local _m302
_m119 = function(param_893, _v894) -- stdlib.ml:567
_v895 = 0
_v896 = old_exit_884(_v895)
return _v896
end
_m192 = function(len_709, ofs_710, s_711, ic_712, _v713) -- stdlib.ml:435
_v715 = invalid_arg_349(_v714)
return _v715
end
_m197 = function(len_679, ofs_680, s_681, ic_682, _v683) -- stdlib.ml:422
_v685 = invalid_arg_349(_v684)
return _v685
end
_m207 = function(oc_644, _v645) -- stdlib.ml:395
local _ok, _res = pcall(function() _v649 = 0
-- stdlib.ml:395
return _v649
end)
if _ok then
exn_648 = _res
else
exn_648 = _res
-- stdlib.ml:395
_v650 = caml_ml_close_channel(oc_644)
-- stdlib.ml:395
end
end
_m217 = function(len_622, ofs_623, s_624, oc_625, _v626) -- stdlib.ml:378
_v628 = invalid_arg_349(_v627)
return _v628
end
_m222 = function(len_604, ofs_605, s_606, oc_607, _v608) -- stdlib.ml:373
_v610 = invalid_arg_349(_v609)
return _v610
end
_m235 = function(param_572, l_573, a_574, _v575) -- stdlib.ml:355
_v576 = iter_560(l_573)
return _v576
end
_m256 = function(i_467, match_468, _v469) -- stdlib.ml:283
return s_457
end
_m257 = function(i_470, match_471, _v472) -- stdlib.ml:282
_v473 = 2
_v474 = int_add(i_470, _v473)
_v475 = loop_459(_v474)
return _v475
end
_m282 = function(n_416, n_417) -- stdlib.ml:224
_v419 = invalid_arg_349(_v418)
return _v419
end
_m302 = function(greet_1018, x_1019, match_1020) _v1021 = {0, greet_1018}
_v1022 = 0
_v1023 = 0
_v1024 = _v1000[104]
-- std_exit.ml:18
_v1025 = _v1024(_v1023)
-- std_exit.ml:18
_v1026 = {0}
_v1027 = 0
return
end
_v945 = caml_ml_set_binary_mode(_v944, _v943)
return _v945
end
_v946 = function(_v947) local _m119
local _m192
local _m197
local _m207
local _m217
local _m222
local _m235
local _m256
local _m257
local _m282
local _m302
_m119 = function(param_893, _v894) -- stdlib.ml:567
_v895 = 0
_v896 = old_exit_884(_v895)
return _v896
end
_m192 = function(len_709, ofs_710, s_711, ic_712, _v713) -- stdlib.ml:435
_v715 = invalid_arg_349(_v714)
return _v715
end
_m197 = function(len_679, ofs_680, s_681, ic_682, _v683) -- stdlib.ml:422
_v685 = invalid_arg_349(_v684)
return _v685
end
_m207 = function(oc_644, _v645) -- stdlib.ml:395
local _ok, _res = pcall(function() _v649 = 0
-- stdlib.ml:395
return _v649
end)
if _ok then
exn_648 = _res
else
exn_648 = _res
-- stdlib.ml:395
_v650 = caml_ml_close_channel(oc_644)
-- stdlib.ml:395
end
end
_m217 = function(len_622, ofs_623, s_624, oc_625, _v626) -- stdlib.ml:378
_v628 = invalid_arg_349(_v627)
return _v628
end
_m222 = function(len_604, ofs_605, s_606, oc_607, _v608) -- stdlib.ml:373
_v610 = invalid_arg_349(_v609)
return _v610
end
_m235 = function(param_572, l_573, a_574, _v575) -- stdlib.ml:355
_v576 = iter_560(l_573)
return _v576
end
_m256 = function(i_467, match_468, _v469) -- stdlib.ml:283
return s_457
end
_m257 = function(i_470, match_471, _v472) -- stdlib.ml:282
_v473 = 2
_v474 = int_add(i_470, _v473)
_v475 = loop_459(_v474)
return _v475
end
_m282 = function(n_416, n_417) -- stdlib.ml:224
_v419 = invalid_arg_349(_v418)
return _v419
end
_m302 = function(greet_1018, x_1019, match_1020) _v1021 = {0, greet_1018}
_v1022 = 0
_v1023 = 0
_v1024 = _v1000[104]
-- std_exit.ml:18
_v1025 = _v1024(_v1023)
-- std_exit.ml:18
_v1026 = {0}
_v1027 = 0
return
end
_v948 = caml_ml_close_channel(_v947)
return _v948
end
_v949 = function(_v950) local _m119
local _m192
local _m197
local _m207
local _m217
local _m222
local _m235
local _m256
local _m257
local _m282
local _m302
_m119 = function(param_893, _v894) -- stdlib.ml:567
_v895 = 0
_v896 = old_exit_884(_v895)
return _v896
end
_m192 = function(len_709, ofs_710, s_711, ic_712, _v713) -- stdlib.ml:435
_v715 = invalid_arg_349(_v714)
return _v715
end
_m197 = function(len_679, ofs_680, s_681, ic_682, _v683) -- stdlib.ml:422
_v685 = invalid_arg_349(_v684)
return _v685
end
_m207 = function(oc_644, _v645) -- stdlib.ml:395
local _ok, _res = pcall(function() _v649 = 0
-- stdlib.ml:395
return _v649
end)
if _ok then
exn_648 = _res
else
exn_648 = _res
-- stdlib.ml:395
_v650 = caml_ml_close_channel(oc_644)
-- stdlib.ml:395
end
end
_m217 = function(len_622, ofs_623, s_624, oc_625, _v626) -- stdlib.ml:378
_v628 = invalid_arg_349(_v627)
return _v628
end
_m222 = function(len_604, ofs_605, s_606, oc_607, _v608) -- stdlib.ml:373
_v610 = invalid_arg_349(_v609)
return _v610
end
_m235 = function(param_572, l_573, a_574, _v575) -- stdlib.ml:355
_v576 = iter_560(l_573)
return _v576
end
_m256 = function(i_467, match_468, _v469) -- stdlib.ml:283
return s_457
end
_m257 = function(i_470, match_471, _v472) -- stdlib.ml:282
_v473 = 2
_v474 = int_add(i_470, _v473)
_v475 = loop_459(_v474)
return _v475
end
_m282 = function(n_416, n_417) -- stdlib.ml:224
_v419 = invalid_arg_349(_v418)
return _v419
end
_m302 = function(greet_1018, x_1019, match_1020) _v1021 = {0, greet_1018}
_v1022 = 0
_v1023 = 0
_v1024 = _v1000[104]
-- std_exit.ml:18
_v1025 = _v1024(_v1023)
-- std_exit.ml:18
_v1026 = {0}
_v1027 = 0
return
end
_v951 = caml_ml_channel_size(_v950)
return _v951
end
_v952 = function(_v953) local _m119
local _m192
local _m197
local _m207
local _m217
local _m222
local _m235
local _m256
local _m257
local _m282
local _m302
_m119 = function(param_893, _v894) -- stdlib.ml:567
_v895 = 0
_v896 = old_exit_884(_v895)
return _v896
end
_m192 = function(len_709, ofs_710, s_711, ic_712, _v713) -- stdlib.ml:435
_v715 = invalid_arg_349(_v714)
return _v715
end
_m197 = function(len_679, ofs_680, s_681, ic_682, _v683) -- stdlib.ml:422
_v685 = invalid_arg_349(_v684)
return _v685
end
_m207 = function(oc_644, _v645) -- stdlib.ml:395
local _ok, _res = pcall(function() _v649 = 0
-- stdlib.ml:395
return _v649
end)
if _ok then
exn_648 = _res
else
exn_648 = _res
-- stdlib.ml:395
_v650 = caml_ml_close_channel(oc_644)
-- stdlib.ml:395
end
end
_m217 = function(len_622, ofs_623, s_624, oc_625, _v626) -- stdlib.ml:378
_v628 = invalid_arg_349(_v627)
return _v628
end
_m222 = function(len_604, ofs_605, s_606, oc_607, _v608) -- stdlib.ml:373
_v610 = invalid_arg_349(_v609)
return _v610
end
_m235 = function(param_572, l_573, a_574, _v575) -- stdlib.ml:355
_v576 = iter_560(l_573)
return _v576
end
_m256 = function(i_467, match_468, _v469) -- stdlib.ml:283
return s_457
end
_m257 = function(i_470, match_471, _v472) -- stdlib.ml:282
_v473 = 2
_v474 = int_add(i_470, _v473)
_v475 = loop_459(_v474)
return _v475
end
_m282 = function(n_416, n_417) -- stdlib.ml:224
_v419 = invalid_arg_349(_v418)
return _v419
end
_m302 = function(greet_1018, x_1019, match_1020) _v1021 = {0, greet_1018}
_v1022 = 0
_v1023 = 0
_v1024 = _v1000[104]
-- std_exit.ml:18
_v1025 = _v1024(_v1023)
-- std_exit.ml:18
_v1026 = {0}
_v1027 = 0
return
end
_v954 = caml_ml_pos_in(_v953)
return _v954
end
_v955 = function(_v957, _v956) local _m119
local _m192
local _m197
local _m207
local _m217
local _m222
local _m235
local _m256
local _m257
local _m282
local _m302
_m119 = function(param_893, _v894) -- stdlib.ml:567
_v895 = 0
_v896 = old_exit_884(_v895)
return _v896
end
_m192 = function(len_709, ofs_710, s_711, ic_712, _v713) -- stdlib.ml:435
_v715 = invalid_arg_349(_v714)
return _v715
end
_m197 = function(len_679, ofs_680, s_681, ic_682, _v683) -- stdlib.ml:422
_v685 = invalid_arg_349(_v684)
return _v685
end
_m207 = function(oc_644, _v645) -- stdlib.ml:395
local _ok, _res = pcall(function() _v649 = 0
-- stdlib.ml:395
return _v649
end)
if _ok then
exn_648 = _res
else
exn_648 = _res
-- stdlib.ml:395
_v650 = caml_ml_close_channel(oc_644)
-- stdlib.ml:395
end
end
_m217 = function(len_622, ofs_623, s_624, oc_625, _v626) -- stdlib.ml:378
_v628 = invalid_arg_349(_v627)
return _v628
end
_m222 = function(len_604, ofs_605, s_606, oc_607, _v608) -- stdlib.ml:373
_v610 = invalid_arg_349(_v609)
return _v610
end
_m235 = function(param_572, l_573, a_574, _v575) -- stdlib.ml:355
_v576 = iter_560(l_573)
return _v576
end
_m256 = function(i_467, match_468, _v469) -- stdlib.ml:283
return s_457
end
_m257 = function(i_470, match_471, _v472) -- stdlib.ml:282
_v473 = 2
_v474 = int_add(i_470, _v473)
_v475 = loop_459(_v474)
return _v475
end
_m282 = function(n_416, n_417) -- stdlib.ml:224
_v419 = invalid_arg_349(_v418)
return _v419
end
_m302 = function(greet_1018, x_1019, match_1020) _v1021 = {0, greet_1018}
_v1022 = 0
_v1023 = 0
_v1024 = _v1000[104]
-- std_exit.ml:18
_v1025 = _v1024(_v1023)
-- std_exit.ml:18
_v1026 = {0}
_v1027 = 0
return
end
_v958 = caml_ml_seek_in(_v957, _v956)
return _v958
end
_v959 = function(_v960) local _m119
local _m192
local _m197
local _m207
local _m217
local _m222
local _m235
local _m256
local _m257
local _m282
local _m302
_m119 = function(param_893, _v894) -- stdlib.ml:567
_v895 = 0
_v896 = old_exit_884(_v895)
return _v896
end
_m192 = function(len_709, ofs_710, s_711, ic_712, _v713) -- stdlib.ml:435
_v715 = invalid_arg_349(_v714)
return _v715
end
_m197 = function(len_679, ofs_680, s_681, ic_682, _v683) -- stdlib.ml:422
_v685 = invalid_arg_349(_v684)
return _v685
end
_m207 = function(oc_644, _v645) -- stdlib.ml:395
local _ok, _res = pcall(function() _v649 = 0
-- stdlib.ml:395
return _v649
end)
if _ok then
exn_648 = _res
else
exn_648 = _res
-- stdlib.ml:395
_v650 = caml_ml_close_channel(oc_644)
-- stdlib.ml:395
end
end
_m217 = function(len_622, ofs_623, s_624, oc_625, _v626) -- stdlib.ml:378
_v628 = invalid_arg_349(_v627)
return _v628
end
_m222 = function(len_604, ofs_605, s_606, oc_607, _v608) -- stdlib.ml:373
_v610 = invalid_arg_349(_v609)
return _v610
end
_m235 = function(param_572, l_573, a_574, _v575) -- stdlib.ml:355
_v576 = iter_560(l_573)
return _v576
end
_m256 = function(i_467, match_468, _v469) -- stdlib.ml:283
return s_457
end
_m257 = function(i_470, match_471, _v472) -- stdlib.ml:282
_v473 = 2
_v474 = int_add(i_470, _v473)
_v475 = loop_459(_v474)
return _v475
end
_m282 = function(n_416, n_417) -- stdlib.ml:224
_v419 = invalid_arg_349(_v418)
return _v419
end
_m302 = function(greet_1018, x_1019, match_1020) _v1021 = {0, greet_1018}
_v1022 = 0
_v1023 = 0
_v1024 = _v1000[104]
-- std_exit.ml:18
_v1025 = _v1024(_v1023)
-- std_exit.ml:18
_v1026 = {0}
_v1027 = 0
return
end
_v961 = caml_input_value(_v960)
return _v961
end
_v962 = function(_v963) local _m119
local _m192
local _m197
local _m207
local _m217
local _m222
local _m235
local _m256
local _m257
local _m282
local _m302
_m119 = function(param_893, _v894) -- stdlib.ml:567
_v895 = 0
_v896 = old_exit_884(_v895)
return _v896
end
_m192 = function(len_709, ofs_710, s_711, ic_712, _v713) -- stdlib.ml:435
_v715 = invalid_arg_349(_v714)
return _v715
end
_m197 = function(len_679, ofs_680, s_681, ic_682, _v683) -- stdlib.ml:422
_v685 = invalid_arg_349(_v684)
return _v685
end
_m207 = function(oc_644, _v645) -- stdlib.ml:395
local _ok, _res = pcall(function() _v649 = 0
-- stdlib.ml:395
return _v649
end)
if _ok then
exn_648 = _res
else
exn_648 = _res
-- stdlib.ml:395
_v650 = caml_ml_close_channel(oc_644)
-- stdlib.ml:395
end
end
_m217 = function(len_622, ofs_623, s_624, oc_625, _v626) -- stdlib.ml:378
_v628 = invalid_arg_349(_v627)
return _v628
end
_m222 = function(len_604, ofs_605, s_606, oc_607, _v608) -- stdlib.ml:373
_v610 = invalid_arg_349(_v609)
return _v610
end
_m235 = function(param_572, l_573, a_574, _v575) -- stdlib.ml:355
_v576 = iter_560(l_573)
return _v576
end
_m256 = function(i_467, match_468, _v469) -- stdlib.ml:283
return s_457
end
_m257 = function(i_470, match_471, _v472) -- stdlib.ml:282
_v473 = 2
_v474 = int_add(i_470, _v473)
_v475 = loop_459(_v474)
return _v475
end
_m282 = function(n_416, n_417) -- stdlib.ml:224
_v419 = invalid_arg_349(_v418)
return _v419
end
_m302 = function(greet_1018, x_1019, match_1020) _v1021 = {0, greet_1018}
_v1022 = 0
_v1023 = 0
_v1024 = _v1000[104]
-- std_exit.ml:18
_v1025 = _v1024(_v1023)
-- std_exit.ml:18
_v1026 = {0}
_v1027 = 0
return
end
_v964 = caml_ml_input_int(_v963)
return _v964
end
_v965 = function(_v966) local _m119
local _m192
local _m197
local _m207
local _m217
local _m222
local _m235
local _m256
local _m257
local _m282
local _m302
_m119 = function(param_893, _v894) -- stdlib.ml:567
_v895 = 0
_v896 = old_exit_884(_v895)
return _v896
end
_m192 = function(len_709, ofs_710, s_711, ic_712, _v713) -- stdlib.ml:435
_v715 = invalid_arg_349(_v714)
return _v715
end
_m197 = function(len_679, ofs_680, s_681, ic_682, _v683) -- stdlib.ml:422
_v685 = invalid_arg_349(_v684)
return _v685
end
_m207 = function(oc_644, _v645) -- stdlib.ml:395
local _ok, _res = pcall(function() _v649 = 0
-- stdlib.ml:395
return _v649
end)
if _ok then
exn_648 = _res
else
exn_648 = _res
-- stdlib.ml:395
_v650 = caml_ml_close_channel(oc_644)
-- stdlib.ml:395
end
end
_m217 = function(len_622, ofs_623, s_624, oc_625, _v626) -- stdlib.ml:378
_v628 = invalid_arg_349(_v627)
return _v628
end
_m222 = function(len_604, ofs_605, s_606, oc_607, _v608) -- stdlib.ml:373
_v610 = invalid_arg_349(_v609)
return _v610
end
_m235 = function(param_572, l_573, a_574, _v575) -- stdlib.ml:355
_v576 = iter_560(l_573)
return _v576
end
_m256 = function(i_467, match_468, _v469) -- stdlib.ml:283
return s_457
end
_m257 = function(i_470, match_471, _v472) -- stdlib.ml:282
_v473 = 2
_v474 = int_add(i_470, _v473)
_v475 = loop_459(_v474)
return _v475
end
_m282 = function(n_416, n_417) -- stdlib.ml:224
_v419 = invalid_arg_349(_v418)
return _v419
end
_m302 = function(greet_1018, x_1019, match_1020) _v1021 = {0, greet_1018}
_v1022 = 0
_v1023 = 0
_v1024 = _v1000[104]
-- std_exit.ml:18
_v1025 = _v1024(_v1023)
-- std_exit.ml:18
_v1026 = {0}
_v1027 = 0
return
end
_v967 = caml_ml_input_char(_v966)
return _v967
end
_v968 = function(_v969) local _m119
local _m192
local _m197
local _m207
local _m217
local _m222
local _m235
local _m256
local _m257
local _m282
local _m302
_m119 = function(param_893, _v894) -- stdlib.ml:567
_v895 = 0
_v896 = old_exit_884(_v895)
return _v896
end
_m192 = function(len_709, ofs_710, s_711, ic_712, _v713) -- stdlib.ml:435
_v715 = invalid_arg_349(_v714)
return _v715
end
_m197 = function(len_679, ofs_680, s_681, ic_682, _v683) -- stdlib.ml:422
_v685 = invalid_arg_349(_v684)
return _v685
end
_m207 = function(oc_644, _v645) -- stdlib.ml:395
local _ok, _res = pcall(function() _v649 = 0
-- stdlib.ml:395
return _v649
end)
if _ok then
exn_648 = _res
else
exn_648 = _res
-- stdlib.ml:395
_v650 = caml_ml_close_channel(oc_644)
-- stdlib.ml:395
end
end
_m217 = function(len_622, ofs_623, s_624, oc_625, _v626) -- stdlib.ml:378
_v628 = invalid_arg_349(_v627)
return _v628
end
_m222 = function(len_604, ofs_605, s_606, oc_607, _v608) -- stdlib.ml:373
_v610 = invalid_arg_349(_v609)
return _v610
end
_m235 = function(param_572, l_573, a_574, _v575) -- stdlib.ml:355
_v576 = iter_560(l_573)
return _v576
end
_m256 = function(i_467, match_468, _v469) -- stdlib.ml:283
return s_457
end
_m257 = function(i_470, match_471, _v472) -- stdlib.ml:282
_v473 = 2
_v474 = int_add(i_470, _v473)
_v475 = loop_459(_v474)
return _v475
end
_m282 = function(n_416, n_417) -- stdlib.ml:224
_v419 = invalid_arg_349(_v418)
return _v419
end
_m302 = function(greet_1018, x_1019, match_1020) _v1021 = {0, greet_1018}
_v1022 = 0
_v1023 = 0
_v1024 = _v1000[104]
-- std_exit.ml:18
_v1025 = _v1024(_v1023)
-- std_exit.ml:18
_v1026 = {0}
_v1027 = 0
return
end
_v970 = caml_ml_input_char(_v969)
return _v970
end
_v971 = function(_v973, _v972) local _m119
local _m192
local _m197
local _m207
local _m217
local _m222
local _m235
local _m256
local _m257
local _m282
local _m302
_m119 = function(param_893, _v894) -- stdlib.ml:567
_v895 = 0
_v896 = old_exit_884(_v895)
return _v896
end
_m192 = function(len_709, ofs_710, s_711, ic_712, _v713) -- stdlib.ml:435
_v715 = invalid_arg_349(_v714)
return _v715
end
_m197 = function(len_679, ofs_680, s_681, ic_682, _v683) -- stdlib.ml:422
_v685 = invalid_arg_349(_v684)
return _v685
end
_m207 = function(oc_644, _v645) -- stdlib.ml:395
local _ok, _res = pcall(function() _v649 = 0
-- stdlib.ml:395
return _v649
end)
if _ok then
exn_648 = _res
else
exn_648 = _res
-- stdlib.ml:395
_v650 = caml_ml_close_channel(oc_644)
-- stdlib.ml:395
end
end
_m217 = function(len_622, ofs_623, s_624, oc_625, _v626) -- stdlib.ml:378
_v628 = invalid_arg_349(_v627)
return _v628
end
_m222 = function(len_604, ofs_605, s_606, oc_607, _v608) -- stdlib.ml:373
_v610 = invalid_arg_349(_v609)
return _v610
end
_m235 = function(param_572, l_573, a_574, _v575) -- stdlib.ml:355
_v576 = iter_560(l_573)
return _v576
end
_m256 = function(i_467, match_468, _v469) -- stdlib.ml:283
return s_457
end
_m257 = function(i_470, match_471, _v472) -- stdlib.ml:282
_v473 = 2
_v474 = int_add(i_470, _v473)
_v475 = loop_459(_v474)
return _v475
end
_m282 = function(n_416, n_417) -- stdlib.ml:224
_v419 = invalid_arg_349(_v418)
return _v419
end
_m302 = function(greet_1018, x_1019, match_1020) _v1021 = {0, greet_1018}
_v1022 = 0
_v1023 = 0
_v1024 = _v1000[104]
-- std_exit.ml:18
_v1025 = _v1024(_v1023)
-- std_exit.ml:18
_v1026 = {0}
_v1027 = 0
return
end
_v974 = caml_ml_set_binary_mode(_v973, _v972)
return _v974
end
_v975 = function(_v976) local _m119
local _m192
local _m197
local _m207
local _m217
local _m222
local _m235
local _m256
local _m257
local _m282
local _m302
_m119 = function(param_893, _v894) -- stdlib.ml:567
_v895 = 0
_v896 = old_exit_884(_v895)
return _v896
end
_m192 = function(len_709, ofs_710, s_711, ic_712, _v713) -- stdlib.ml:435
_v715 = invalid_arg_349(_v714)
return _v715
end
_m197 = function(len_679, ofs_680, s_681, ic_682, _v683) -- stdlib.ml:422
_v685 = invalid_arg_349(_v684)
return _v685
end
_m207 = function(oc_644, _v645) -- stdlib.ml:395
local _ok, _res = pcall(function() _v649 = 0
-- stdlib.ml:395
return _v649
end)
if _ok then
exn_648 = _res
else
exn_648 = _res
-- stdlib.ml:395
_v650 = caml_ml_close_channel(oc_644)
-- stdlib.ml:395
end
end
_m217 = function(len_622, ofs_623, s_624, oc_625, _v626) -- stdlib.ml:378
_v628 = invalid_arg_349(_v627)
return _v628
end
_m222 = function(len_604, ofs_605, s_606, oc_607, _v608) -- stdlib.ml:373
_v610 = invalid_arg_349(_v609)
return _v610
end
_m235 = function(param_572, l_573, a_574, _v575) -- stdlib.ml:355
_v576 = iter_560(l_573)
return _v576
end
_m256 = function(i_467, match_468, _v469) -- stdlib.ml:283
return s_457
end
_m257 = function(i_470, match_471, _v472) -- stdlib.ml:282
_v473 = 2
_v474 = int_add(i_470, _v473)
_v475 = loop_459(_v474)
return _v475
end
_m282 = function(n_416, n_417) -- stdlib.ml:224
_v419 = invalid_arg_349(_v418)
return _v419
end
_m302 = function(greet_1018, x_1019, match_1020) _v1021 = {0, greet_1018}
_v1022 = 0
_v1023 = 0
_v1024 = _v1000[104]
-- std_exit.ml:18
_v1025 = _v1024(_v1023)
-- std_exit.ml:18
_v1026 = {0}
_v1027 = 0
return
end
_v977 = caml_ml_channel_size(_v976)
return _v977
end
_v978 = function(_v979) local _m119
local _m192
local _m197
local _m207
local _m217
local _m222
local _m235
local _m256
local _m257
local _m282
local _m302
_m119 = function(param_893, _v894) -- stdlib.ml:567
_v895 = 0
_v896 = old_exit_884(_v895)
return _v896
end
_m192 = function(len_709, ofs_710, s_711, ic_712, _v713) -- stdlib.ml:435
_v715 = invalid_arg_349(_v714)
return _v715
end
_m197 = function(len_679, ofs_680, s_681, ic_682, _v683) -- stdlib.ml:422
_v685 = invalid_arg_349(_v684)
return _v685
end
_m207 = function(oc_644, _v645) -- stdlib.ml:395
local _ok, _res = pcall(function() _v649 = 0
-- stdlib.ml:395
return _v649
end)
if _ok then
exn_648 = _res
else
exn_648 = _res
-- stdlib.ml:395
_v650 = caml_ml_close_channel(oc_644)
-- stdlib.ml:395
end
end
_m217 = function(len_622, ofs_623, s_624, oc_625, _v626) -- stdlib.ml:378
_v628 = invalid_arg_349(_v627)
return _v628
end
_m222 = function(len_604, ofs_605, s_606, oc_607, _v608) -- stdlib.ml:373
_v610 = invalid_arg_349(_v609)
return _v610
end
_m235 = function(param_572, l_573, a_574, _v575) -- stdlib.ml:355
_v576 = iter_560(l_573)
return _v576
end
_m256 = function(i_467, match_468, _v469) -- stdlib.ml:283
return s_457
end
_m257 = function(i_470, match_471, _v472) -- stdlib.ml:282
_v473 = 2
_v474 = int_add(i_470, _v473)
_v475 = loop_459(_v474)
return _v475
end
_m282 = function(n_416, n_417) -- stdlib.ml:224
_v419 = invalid_arg_349(_v418)
return _v419
end
_m302 = function(greet_1018, x_1019, match_1020) _v1021 = {0, greet_1018}
_v1022 = 0
_v1023 = 0
_v1024 = _v1000[104]
-- std_exit.ml:18
_v1025 = _v1024(_v1023)
-- std_exit.ml:18
_v1026 = {0}
_v1027 = 0
return
end
_v980 = caml_ml_pos_out(_v979)
return _v980
end
_v981 = function(_v983, _v982) local _m119
local _m192
local _m197
local _m207
local _m217
local _m222
local _m235
local _m256
local _m257
local _m282
local _m302
_m119 = function(param_893, _v894) -- stdlib.ml:567
_v895 = 0
_v896 = old_exit_884(_v895)
return _v896
end
_m192 = function(len_709, ofs_710, s_711, ic_712, _v713) -- stdlib.ml:435
_v715 = invalid_arg_349(_v714)
return _v715
end
_m197 = function(len_679, ofs_680, s_681, ic_682, _v683) -- stdlib.ml:422
_v685 = invalid_arg_349(_v684)
return _v685
end
_m207 = function(oc_644, _v645) -- stdlib.ml:395
local _ok, _res = pcall(function() _v649 = 0
-- stdlib.ml:395
return _v649
end)
if _ok then
exn_648 = _res
else
exn_648 = _res
-- stdlib.ml:395
_v650 = caml_ml_close_channel(oc_644)
-- stdlib.ml:395
end
end
_m217 = function(len_622, ofs_623, s_624, oc_625, _v626) -- stdlib.ml:378
_v628 = invalid_arg_349(_v627)
return _v628
end
_m222 = function(len_604, ofs_605, s_606, oc_607, _v608) -- stdlib.ml:373
_v610 = invalid_arg_349(_v609)
return _v610
end
_m235 = function(param_572, l_573, a_574, _v575) -- stdlib.ml:355
_v576 = iter_560(l_573)
return _v576
end
_m256 = function(i_467, match_468, _v469) -- stdlib.ml:283
return s_457
end
_m257 = function(i_470, match_471, _v472) -- stdlib.ml:282
_v473 = 2
_v474 = int_add(i_470, _v473)
_v475 = loop_459(_v474)
return _v475
end
_m282 = function(n_416, n_417) -- stdlib.ml:224
_v419 = invalid_arg_349(_v418)
return _v419
end
_m302 = function(greet_1018, x_1019, match_1020) _v1021 = {0, greet_1018}
_v1022 = 0
_v1023 = 0
_v1024 = _v1000[104]
-- std_exit.ml:18
_v1025 = _v1024(_v1023)
-- std_exit.ml:18
_v1026 = {0}
_v1027 = 0
return
end
_v984 = caml_ml_seek_out(_v983, _v982)
return _v984
end
_v985 = function(_v987, _v986) local _m119
local _m192
local _m197
local _m207
local _m217
local _m222
local _m235
local _m256
local _m257
local _m282
local _m302
_m119 = function(param_893, _v894) -- stdlib.ml:567
_v895 = 0
_v896 = old_exit_884(_v895)
return _v896
end
_m192 = function(len_709, ofs_710, s_711, ic_712, _v713) -- stdlib.ml:435
_v715 = invalid_arg_349(_v714)
return _v715
end
_m197 = function(len_679, ofs_680, s_681, ic_682, _v683) -- stdlib.ml:422
_v685 = invalid_arg_349(_v684)
return _v685
end
_m207 = function(oc_644, _v645) -- stdlib.ml:395
local _ok, _res = pcall(function() _v649 = 0
-- stdlib.ml:395
return _v649
end)
if _ok then
exn_648 = _res
else
exn_648 = _res
-- stdlib.ml:395
_v650 = caml_ml_close_channel(oc_644)
-- stdlib.ml:395
end
end
_m217 = function(len_622, ofs_623, s_624, oc_625, _v626) -- stdlib.ml:378
_v628 = invalid_arg_349(_v627)
return _v628
end
_m222 = function(len_604, ofs_605, s_606, oc_607, _v608) -- stdlib.ml:373
_v610 = invalid_arg_349(_v609)
return _v610
end
_m235 = function(param_572, l_573, a_574, _v575) -- stdlib.ml:355
_v576 = iter_560(l_573)
return _v576
end
_m256 = function(i_467, match_468, _v469) -- stdlib.ml:283
return s_457
end
_m257 = function(i_470, match_471, _v472) -- stdlib.ml:282
_v473 = 2
_v474 = int_add(i_470, _v473)
_v475 = loop_459(_v474)
return _v475
end
_m282 = function(n_416, n_417) -- stdlib.ml:224
_v419 = invalid_arg_349(_v418)
return _v419
end
_m302 = function(greet_1018, x_1019, match_1020) _v1021 = {0, greet_1018}
_v1022 = 0
_v1023 = 0
_v1024 = _v1000[104]
-- std_exit.ml:18
_v1025 = _v1024(_v1023)
-- std_exit.ml:18
_v1026 = {0}
_v1027 = 0
return
end
_v988 = caml_ml_output_int(_v987, _v986)
return _v988
end
_v989 = function(_v991, _v990) local _m119
local _m192
local _m197
local _m207
local _m217
local _m222
local _m235
local _m256
local _m257
local _m282
local _m302
_m119 = function(param_893, _v894) -- stdlib.ml:567
_v895 = 0
_v896 = old_exit_884(_v895)
return _v896
end
_m192 = function(len_709, ofs_710, s_711, ic_712, _v713) -- stdlib.ml:435
_v715 = invalid_arg_349(_v714)
return _v715
end
_m197 = function(len_679, ofs_680, s_681, ic_682, _v683) -- stdlib.ml:422
_v685 = invalid_arg_349(_v684)
return _v685
end
_m207 = function(oc_644, _v645) -- stdlib.ml:395
local _ok, _res = pcall(function() _v649 = 0
-- stdlib.ml:395
return _v649
end)
if _ok then
exn_648 = _res
else
exn_648 = _res
-- stdlib.ml:395
_v650 = caml_ml_close_channel(oc_644)
-- stdlib.ml:395
end
end
_m217 = function(len_622, ofs_623, s_624, oc_625, _v626) -- stdlib.ml:378
_v628 = invalid_arg_349(_v627)
return _v628
end
_m222 = function(len_604, ofs_605, s_606, oc_607, _v608) -- stdlib.ml:373
_v610 = invalid_arg_349(_v609)
return _v610
end
_m235 = function(param_572, l_573, a_574, _v575) -- stdlib.ml:355
_v576 = iter_560(l_573)
return _v576
end
_m256 = function(i_467, match_468, _v469) -- stdlib.ml:283
return s_457
end
_m257 = function(i_470, match_471, _v472) -- stdlib.ml:282
_v473 = 2
_v474 = int_add(i_470, _v473)
_v475 = loop_459(_v474)
return _v475
end
_m282 = function(n_416, n_417) -- stdlib.ml:224
_v419 = invalid_arg_349(_v418)
return _v419
end
_m302 = function(greet_1018, x_1019, match_1020) _v1021 = {0, greet_1018}
_v1022 = 0
_v1023 = 0
_v1024 = _v1000[104]
-- std_exit.ml:18
_v1025 = _v1024(_v1023)
-- std_exit.ml:18
_v1026 = {0}
_v1027 = 0
return
end
_v992 = caml_ml_output_char(_v991, _v990)
return _v992
end
_v993 = function(_v995, _v994) local _m119
local _m192
local _m197
local _m207
local _m217
local _m222
local _m235
local _m256
local _m257
local _m282
local _m302
_m119 = function(param_893, _v894) -- stdlib.ml:567
_v895 = 0
_v896 = old_exit_884(_v895)
return _v896
end
_m192 = function(len_709, ofs_710, s_711, ic_712, _v713) -- stdlib.ml:435
_v715 = invalid_arg_349(_v714)
return _v715
end
_m197 = function(len_679, ofs_680, s_681, ic_682, _v683) -- stdlib.ml:422
_v685 = invalid_arg_349(_v684)
return _v685
end
_m207 = function(oc_644, _v645) -- stdlib.ml:395
local _ok, _res = pcall(function() _v649 = 0
-- stdlib.ml:395
return _v649
end)
if _ok then
exn_648 = _res
else
exn_648 = _res
-- stdlib.ml:395
_v650 = caml_ml_close_channel(oc_644)
-- stdlib.ml:395
end
end
_m217 = function(len_622, ofs_623, s_624, oc_625, _v626) -- stdlib.ml:378
_v628 = invalid_arg_349(_v627)
return _v628
end
_m222 = function(len_604, ofs_605, s_606, oc_607, _v608) -- stdlib.ml:373
_v610 = invalid_arg_349(_v609)
return _v610
end
_m235 = function(param_572, l_573, a_574, _v575) -- stdlib.ml:355
_v576 = iter_560(l_573)
return _v576
end
_m256 = function(i_467, match_468, _v469) -- stdlib.ml:283
return s_457
end
_m257 = function(i_470, match_471, _v472) -- stdlib.ml:282
_v473 = 2
_v474 = int_add(i_470, _v473)
_v475 = loop_459(_v474)
return _v475
end
_m282 = function(n_416, n_417) -- stdlib.ml:224
_v419 = invalid_arg_349(_v418)
return _v419
end
_m302 = function(greet_1018, x_1019, match_1020) _v1021 = {0, greet_1018}
_v1022 = 0
_v1023 = 0
_v1024 = _v1000[104]
-- std_exit.ml:18
_v1025 = _v1024(_v1023)
-- std_exit.ml:18
_v1026 = {0}
_v1027 = 0
return
end
_v996 = caml_ml_output_char(_v995, _v994)
return _v996
end
_v997 = function(_v998) local _m119
local _m192
local _m197
local _m207
local _m217
local _m222
local _m235
local _m256
local _m257
local _m282
local _m302
_m119 = function(param_893, _v894) -- stdlib.ml:567
_v895 = 0
_v896 = old_exit_884(_v895)
return _v896
end
_m192 = function(len_709, ofs_710, s_711, ic_712, _v713) -- stdlib.ml:435
_v715 = invalid_arg_349(_v714)
return _v715
end
_m197 = function(len_679, ofs_680, s_681, ic_682, _v683) -- stdlib.ml:422
_v685 = invalid_arg_349(_v684)
return _v685
end
_m207 = function(oc_644, _v645) -- stdlib.ml:395
local _ok, _res = pcall(function() _v649 = 0
-- stdlib.ml:395
return _v649
end)
if _ok then
exn_648 = _res
else
exn_648 = _res
-- stdlib.ml:395
_v650 = caml_ml_close_channel(oc_644)
-- stdlib.ml:395
end
end
_m217 = function(len_622, ofs_623, s_624, oc_625, _v626) -- stdlib.ml:378
_v628 = invalid_arg_349(_v627)
return _v628
end
_m222 = function(len_604, ofs_605, s_606, oc_607, _v608) -- stdlib.ml:373
_v610 = invalid_arg_349(_v609)
return _v610
end
_m235 = function(param_572, l_573, a_574, _v575) -- stdlib.ml:355
_v576 = iter_560(l_573)
return _v576
end
_m256 = function(i_467, match_468, _v469) -- stdlib.ml:283
return s_457
end
_m257 = function(i_470, match_471, _v472) -- stdlib.ml:282
_v473 = 2
_v474 = int_add(i_470, _v473)
_v475 = loop_459(_v474)
return _v475
end
_m282 = function(n_416, n_417) -- stdlib.ml:224
_v419 = invalid_arg_349(_v418)
return _v419
end
_m302 = function(greet_1018, x_1019, match_1020) _v1021 = {0, greet_1018}
_v1022 = 0
_v1023 = 0
_v1024 = _v1000[104]
-- std_exit.ml:18
_v1025 = _v1024(_v1023)
-- std_exit.ml:18
_v1026 = {0}
_v1027 = 0
return
end
_v999 = caml_ml_flush(_v998)
return _v999
end
_v1000 = {0, invalid_arg_349, failwith_345, Exit_355, Match_failure_356, Assert_failure_357, Invalid_argument_341, Failure_347, Not_found_358, Out_of_memory_359, Stack_overflow_360, Sys_error_361, End_of_file_362, Division_by_zero_363, Sys_blocked_io_364, Undefined_recursive_module_365, min_366, max_370, abs_374, max_int_384, min_int_386, lnot_378, infinity_388, neg_infinity_390, nan_392, max_float_394, min_float_396, epsilon_float_398, symbol_concat_399, char_of_int_412, string_of_bool_420, bool_of_string_opt_434, bool_of_string_424, string_of_int_443, int_of_string_opt_447, string_of_float_479, float_of_string_opt_484, symbol_493, stdin_536, stdout_538, stderr_540, print_char_781, print_string_784, print_bytes_787, print_int_790, print_float_794, print_endline_798, print_newline_804, prerr_char_809, prerr_string_812, prerr_bytes_815, prerr_int_818, prerr_float_822, prerr_endline_826, prerr_newline_832, read_line_837, read_int_opt_846, read_int_841, read_float_opt_856, read_float_851, open_out_548, open_out_bin_553, open_out_gen_541, _v997, flush_all_558, _v993, output_string_588, output_bytes_582, output_594, output_substring_612, _v989, _v985, output_value_630, _v981, _v978, _v975, close_out_635, close_out_noerr_639, _v971, open_in_659, open_in_bin_664, open_in_gen_652, _v968, input_line_724, input_669, really_input_699, really_input_string_717, _v965, _v962, _v959, _v955, _v952, _v949, _v946, close_in_noerr_775, _v942, _v941, string_of_format_862, symbol_865, exit_914, at_exit_879, valid_float_lexem_456, unsafe_really_input_687, do_at_exit_905, do_domain_local_at_exit_904}
_v1001 = 0
greet_1002 = function(name_1003) -- hello.ml:3
local _m119
local _m192
local _m197
local _m207
local _m217
local _m222
local _m235
local _m256
local _m257
local _m282
local _m302
_m119 = function(param_893, _v894) -- stdlib.ml:567
_v895 = 0
_v896 = old_exit_884(_v895)
return _v896
end
_m192 = function(len_709, ofs_710, s_711, ic_712, _v713) -- stdlib.ml:435
_v715 = invalid_arg_349(_v714)
return _v715
end
_m197 = function(len_679, ofs_680, s_681, ic_682, _v683) -- stdlib.ml:422
_v685 = invalid_arg_349(_v684)
return _v685
end
_m207 = function(oc_644, _v645) -- stdlib.ml:395
local _ok, _res = pcall(function() _v649 = 0
-- stdlib.ml:395
return _v649
end)
if _ok then
exn_648 = _res
else
exn_648 = _res
-- stdlib.ml:395
_v650 = caml_ml_close_channel(oc_644)
-- stdlib.ml:395
end
end
_m217 = function(len_622, ofs_623, s_624, oc_625, _v626) -- stdlib.ml:378
_v628 = invalid_arg_349(_v627)
return _v628
end
_m222 = function(len_604, ofs_605, s_606, oc_607, _v608) -- stdlib.ml:373
_v610 = invalid_arg_349(_v609)
return _v610
end
_m235 = function(param_572, l_573, a_574, _v575) -- stdlib.ml:355
_v576 = iter_560(l_573)
return _v576
end
_m256 = function(i_467, match_468, _v469) -- stdlib.ml:283
return s_457
end
_m257 = function(i_470, match_471, _v472) -- stdlib.ml:282
_v473 = 2
_v474 = int_add(i_470, _v473)
_v475 = loop_459(_v474)
return _v475
end
_m282 = function(n_416, n_417) -- stdlib.ml:224
_v419 = invalid_arg_349(_v418)
return _v419
end
_m302 = function(greet_1018, x_1019, match_1020) _v1021 = {0, greet_1018}
_v1022 = 0
_v1023 = 0
_v1024 = _v1000[104]
-- std_exit.ml:18
_v1025 = _v1024(_v1023)
-- std_exit.ml:18
_v1026 = {0}
_v1027 = 0
return
end
-- hello.ml:2
_v1005 = _v1000[29]
-- hello.ml:2
msg_1006 = _v1005(_v1004, name_1003)
-- hello.ml:3
_v1007 = _v1000[47]
_v1008 = _v1007(msg_1006)
return _v1008
end
-- hello.ml:6
_v1010 = greet_1002(_v1009)
-- hello.ml:6
_v1011 = 2
_v1012 = 4
x_1013 = int_add(_v1011, _v1012)
-- hello.ml:8
_v1014 = 6 == x_1013
if _v1014 then
-- hello.ml:9
_v1016 = _v1000[43]
-- hello.ml:9
_v1017 = _v1016(_v1015)
-- hello.ml:9
return _m302(greet_1002, x_1013, _v1017)
else
-- hello.ml:11
_v1029 = _v1000[43]
-- hello.ml:11
_v1030 = _v1029(_v1028)
-- hello.ml:11
return _m302(greet_1002, x_1013, _v1030)
end
 end
_main()
_main()
