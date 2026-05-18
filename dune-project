(lang dune 3.20)
(name lua_of_ocaml)
(generate_opam_files true)

(package
 (name lua_of_ocaml)
 (allow_empty)
 (synopsis "OCaml to Lua 5.1 compiler")
 (description "A compiler from OCaml bytecode to Lua 5.1, inspired by js_of_ocaml.")
 (depends
  (ocaml (>= 4.13))
  (js_of_ocaml-compiler (>= 6.2.0))
  (dune (>= 3.20))
  (odoc :with-doc)))