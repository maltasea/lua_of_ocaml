-- lua_of_ocaml runtime: block and object operations
-- Provides: caml_obj_tag caml_obj_block caml_obj_dup caml_obj_set_raw_field
--           direct_obj_tag

function caml_obj_tag(b)
  if type(b) == "table" then return b[1] or 0 else return 0 end
end

-- %direct_obj_tag — used by the IR to drive Switch on block tags.
-- Returns the OCaml-encoded tag (2 * raw) so it matches the encoded case
-- indices the codegen emits (see generate_lua.ml Code.Switch).
function direct_obj_tag(b)
  if type(b) == "table" then return (b[1] or 0) * 2 else return 0 end
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

-- ---- Object machinery (camlinternalOO) ----
-- An OCaml object is a block {248, methods_table, oo_id}, where methods
-- is itself a block whose layout is:
--   meths[1] = tag (block header)
--   meths[2] = encoded number of methods (2*n)
--   meths[3] = padding
--   meths[4], meths[5] = first method's (function, tag)
--   meths[6], meths[7] = second method's (function, tag)
--   ...
-- Tags here are method-name hashes — already-encoded OCaml ints.
function caml_get_public_method(obj, tag)
  local meths = obj[2]
  if type(meths) ~= "table" then return 0 end
  local nmeths = math.floor((meths[2] or 0) / 2)
  for i = 0, nmeths - 1 do
    local pos = 4 + i * 2
    if meths[pos + 1] == tag then return meths[pos] end
  end
  return 0
end

caml_method_cache = {}
function caml_oo_cache_id() return 0 end
function caml_get_cached_method(obj, tag, _cacheid)
  return caml_get_public_method(obj, tag)
end

function caml_set_oo_id(b)
  -- jsoo uses post-increment so the first id handed out is 0.
  local id = caml_oo_last_id or 0
  b[3] = id * 2
  caml_oo_last_id = id + 1
  return b
end
