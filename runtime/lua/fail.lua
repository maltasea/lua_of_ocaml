-- lua_of_ocaml runtime: exceptions
-- Provides: caml_failwith caml_invalid_argument caml_raise

function caml_failwith(msg) error(msg) end
function caml_invalid_argument(msg) error("Invalid_argument: " .. msg) end
_caml_exn = nil

function caml_raise(exn)
  _caml_exn = exn
  error("caml_exn")
end
