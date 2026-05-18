FFI Tests — OCaml ↔ Lua interop

The Compiler Bridge
-------------------
OCaml bytecode "Extern" primitives become direct Lua function calls.
Any Lua global function in the runtime is callable from OCaml code
that compiles to an Extern primitive.  For example:

  OCaml source              IR primitive          Generated Lua
  -----------------------   -------------------   ------------------
  output_char stdout 'x'    Extern "caml_ml_output_char"   caml_ml_output_char(...)
  let s = "hi" ^ "lo"       Extern "caml_string_concat"   caml_string_concat(...)
  let r = a * b             Extern "%int_mul"              int_mul(a, b)

OCaml closures become Lua functions and can be stored in
caml_global_data for Lua code to call back.

Tests
-----
  make test    — run the Lua-side FFI tests (17 assertions)
