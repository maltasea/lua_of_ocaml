lua_of_ocaml — OCaml to Lua 5.1 Compiler
==========================================

Compiles OCaml bytecode programs to Lua 5.1, inspired by js_of_ocaml.

> **Note:** this project was written in a heavily guided, multi-hour
> chat session with Claude Code (Claude Opus 4.7) — nothing agentic.

## Source tracing (MVP)

Generated Lua includes `-- file:line` comments at closure boundaries and
block entry points, mapping back to the original OCaml source. Compile
your OCaml with `-g` to include debug info:

    ocamlc -g -o hello.byte hello.ml
First steps
-----------

### 1. Install

You need OCaml, dune, Lua 5.1, and the js_of_ocaml compiler library:

    opam install js_of_ocaml-compiler

Clone and build:

    git clone git@github.com:maltasea/lua_of_ocaml.git
    cd lua_of_ocaml
    dune build

The compiler is at `_build/default/compiler/bin-lua_of_ocaml/main.exe`.

### 2. Write an OCaml program

    (* hello.ml *)
    let () = print_endline "hello from lua"

### 3. Compile to bytecode

    ocamlc -o hello.byte hello.ml

### 4. Run lua_of_ocaml

    dune exec -- compiler/bin-lua_of_ocaml/main.exe -- hello.byte -o hello.lua

### 5. Run with Lua

    lua hello.lua

    hello from lua

Architecture
------------

    OCaml source
      ocamlc
        bytecode (.byte)
          js_of_ocaml parser  (reused)
            IR (Code.program)
              lua_of_ocaml code generator  (generate_lua.ml)
                Lua AST
                  lua_output.ml
                    .lua text
                      + runtime_lua.ml  (embedded Lua primitives)
                        lua hello.lua

The IR (Code.program) from js_of_ocaml is target-agnostic. lua_of_ocaml
reuses the bytecode parser and optimizations, and provides a structural
CFG code generator modeled on js_of_ocaml's generate.ml.

Files
-----

    compiler/lib/lua.ml            Lua 5.1 AST
    compiler/lib/lua_output.ml     Lua pretty printer
    compiler/lib/generate_lua.ml   Code generator (IR -> Lua)
    compiler/lib/runtime_lua.ml    OCaml runtime in Lua (embedded)
    compiler/bin-lua_of_ocaml/     CLI entry point
    test/hello.ml                  Example OCaml program

License
-------
LGPL-2.1-or-later WITH OCaml-LGPL-linking-exception
(same as js_of_ocaml)
