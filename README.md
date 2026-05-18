lua_of_ocaml — OCaml to Lua Compiler
====================================

Compiles OCaml programs to Lua 5.1, inspired by js_of_ocaml.

Prerequisites
-------------
- OCaml 4.13+ (tested with 5.4.0)
- Dune 3.20+
- Lua 5.1 at /usr/local/bin/lua
- js_of_ocaml-compiler installed via opam

  opam install js_of_ocaml-compiler

Build
-----
  dune build

This produces the compiler at:
  _build/default/compiler/bin-lua_of_ocaml/main.exe

Usage
-----
Write an OCaml program:

  (* hello.ml *)
  let () = print_endline "hello from lua"

Compile it to OCaml bytecode:

  ocamlc -o hello.byte hello.ml

Run lua_of_ocaml:

  dune exec -- compiler/bin-lua_of_ocaml/main.exe -- hello.byte -o hello.lua

Run the generated Lua:

  /usr/local/bin/lua hello.lua

Architecture
------------
OCaml source → ocamlc → bytecode → [jsoo parser] → IR → [lua_of_ocaml] → .lua

lua_of_ocaml reuses js_of_ocaml's bytecode parser and optimizer (the IR is
target-agnostic), and provides a new Lua code generator and runtime.

Files
-----
compiler/lib/lua.ml          Lua 5.1 AST
compiler/lib/lua.mli         Lua 5.1 AST (interface)
compiler/lib/lua_output.ml   Lua pretty printer (AST → text)
compiler/lib/generate_lua.ml Code generator (jsoo IR → Lua AST)
compiler/lib/runtime_lua.ml  OCaml runtime in Lua (embedded primitives)
compiler/bin-lua_of_ocaml/   CLI entry point

License
-------
LGPL-2.1-or-later WITH OCaml-LGPL-linking-exception
(same as js_of_ocaml)
