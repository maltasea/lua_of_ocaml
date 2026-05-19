# lua_bind_gen — C Header to LuaJIT FFI + OCaml Bindings

Takes a C header file and generates three files:

- `*_external.ml` — OCaml `external` declarations (callable from OCaml)
- `*_stubs.c` — Dummy C stubs for ocamlc linking (never executed)
- `*_bindings.lua` — LuaJIT FFI bindings + value-converting wrappers

## Build & Run

Requires OCaml 4.13+ with the `str` library.

    ocaml -I +str str.cma lua_bind_gen.ml [--prefix PREFIX] <header.h>

    # Example: strip "RLAPI " prefix from raylib functions
    ocaml -I +str str.cma lua_bind_gen.ml --prefix "RLAPI " raylib.h

## Output

### *_external.ml

OCaml `external` declarations. One per C function:

    external init_window : int -> int -> string -> unit = "init_window"
    external draw_rectangle : int -> int -> int -> int -> int -> unit = "draw_rectangle"

C type mapping:
- `int`, `unsigned` → `int` (tagged OCaml int)
- `float`, `double` → `float` (boxed OCaml float)
- `bool` → `bool`
- `void` → `unit`
- `const char *` → `string`
- Structs, enums, pointers → `int` (opaque)

### *_stubs.c

Empty C functions — needed only so ocamlc can link the bytecode. The
lua_of_ocaml compiler replaces these calls with direct Lua calls.

    #include <caml/mlvalues.h>
    CAMLprim value init_window(value v1,value v2,value v3) {... return Val_unit;}
    CAMLprim value draw_rectangle(value v1,value v2,...) {... return Val_unit;}

### *_bindings.lua

LuaJIT FFI declarations and wrapper functions that convert OCaml values
to C values before calling the C function:

    local ffi = require("ffi")
    ffi.cdef([[
      void InitWindow(int w, int h, const char *title);
      void DrawRectangle(int x, int y, int w, int h, Color color);
    ]])

    function init_window(a1, a2, a3)
      return C.InitWindow(ocaml_int(a1), ocaml_int(a2), ocaml_string(a3))
    end

OCaml value conversion helpers are included:
- `ocaml_int(v)` — tagged int (/2) to Lua number
- `ocaml_float(v)` — boxed float `{253, value}` to Lua number
- `ocaml_string(v)` — identity passthrough

## Putting It Together

    # Generate bindings from header
    ocaml -I +str str.cma lua_bind_gen.ml --prefix "RLAPI " raylib.h
    # -> raylib_external.ml, raylib_stubs.c, raylib_bindings.lua

    # Write your OCaml game using the generated externals
    echo 'open Raylib_external' > game.ml
    echo 'let () = init_window 600 400 "hello"' >> game.ml

    # Compile with C stubs, run through lua_of_ocaml
    ocamlc -c raylib_stubs.c
    ocamlc -c game.ml
    ocamlc -custom -o game.byte raylib_stubs.o game.cmo
    loo.sh game.byte -o game.lua

    # game.lua requires the generated _bindings.lua + raylib shared library
    cat raylib_bindings.lua game.lua > main.lua
    luajit main.lua
