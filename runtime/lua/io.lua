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
