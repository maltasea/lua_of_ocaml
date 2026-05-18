(* lua_of_ocaml FFI walkthrough

   How it works:
   1. OCaml compiles to bytecode
   2. The IR contains Extern primitives (e.g. Extern "math_sqrt")
   3. Our code generator emits a Lua call: math_sqrt(...)
   4. At runtime, Lua's global math_sqrt executes

   So any Lua global function is automatically callable from OCaml
   if the OCaml compiler emits it as an Extern primitive.  *)

(* ---- Example: write a Lua-side function in the runtime ---- *)

(* In runtime/lua/misc.lua (or a user-supplied .lua file):
     function lu_hello(name)
       print("hello " .. name)
       return name .. "!"
     end

   Then in OCaml, the Extern primitive calls lu_hello directly.
   The compiler emits:  lu_hello("world")  *)

(* ---- Example: call Lua builtins ---- *)

(* Lua's math.sqrt is math_sqrt in the runtime (math.floor = math_floor, etc.)
   These are already defined in runtime/lua/ints.lua as Lua globals.
   OCaml code calls them via the bytecode Extern mechanism. *)

(* ---- Example: OCaml callback passed to Lua ---- *)

(* OCaml closures become Lua functions.  The runtime's caml_global_data
   table can store them by name.  Lua code then calls them back:

   -- In Lua:
   local fn = caml_global_data["my_callback"]
   local result = fn(42)

   -- result is an OCaml-tagged integer (84 = 42*2) *)

let () = print_endline "FFI: see comments in test/ffi.ml"
