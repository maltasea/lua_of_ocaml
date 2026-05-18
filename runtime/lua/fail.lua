-- lua_of_ocaml runtime: exceptions
-- Provides: caml_failwith caml_invalid_argument caml_raise

function caml_failwith(msg) error(msg) end
function caml_invalid_argument(msg) error("Invalid_argument: " .. msg) end
function caml_raise(exn)
  -- TODO: propagate via pcall; for now return sentinel
  return 0
end
