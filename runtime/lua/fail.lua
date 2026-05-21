-- lua_of_ocaml runtime: exceptions
-- Provides: caml_failwith caml_invalid_argument caml_raise caml_prim_missing
--           caml_exn_describe

function caml_failwith(msg) error("Failure: " .. tostring(msg)) end
function caml_invalid_argument(msg) error("Invalid_argument: " .. tostring(msg)) end
_caml_exn = nil

-- Describe an OCaml exception value for Lua's traceback.
-- Exception value is a block {tag, exn_id_block, ...payload}, where
-- exn_id_block is {248, name_string, fresh_id}.  We pull the name out
-- so the error message names the OCaml exception instead of just
-- saying "caml_exn".
function caml_exn_describe(exn)
  if type(exn) ~= "table" then return tostring(exn) end
  local id = exn[2]
  if type(id) == "table" and type(id[2]) == "string" then
    local name = id[2]
    -- Some exceptions carry a string payload: Failure of string,
    -- Invalid_argument of string, Sys_error of string.
    if exn[3] and type(exn[3]) == "string" then
      return name .. ": " .. exn[3]
    end
    return name
  end
  return "(unknown exception)"
end

function caml_raise(exn)
  _caml_exn = exn
  error(caml_exn_describe(exn))
end

-- Last-resort handler for IR primitives that fall through unhandled.
-- generate_lua.ml emits a call to this with a label naming the
-- primitive so the error message is actionable.
function caml_prim_missing(label, ...)
  error("unhandled IR primitive: " .. tostring(label))
end
