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
