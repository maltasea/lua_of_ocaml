LUA ?= luajit

.PHONY: build test clean hello run help

build: loo
	dune build

loo: misc/loo.in
	sed "s|@ROOT@|$(shell pwd)|" misc/loo.in > loo
	chmod +x loo

test:
	LUA=$(LUA) bash test/run_all.sh

clean:
	dune clean
	rm -rf test/_out
	rm -f hello*
	find . -name '*.byte' -o -name '*.cmi' -o -name '*.cmo' -o -name '*.cma' | xargs rm -f

hello.ml:
	@echo 'let () = print_endline "hello from lua"' > hello.ml

hello: build hello.ml
	ocamlc -g -o hello.byte hello.ml
	dune exec -- compiler/bin-lua_of_ocaml/main.exe -- hello.byte -o hello.lua
	@rm -f hello.byte hello.cmi hello.cmo
	$(LUA) hello.lua

run: build
	dune exec -- compiler/bin-lua_of_ocaml/main.exe -- $(FILE)

help:
	@echo "lua_of_ocaml - OCaml to Lua 5.1 compiler"
	@echo ""
	@echo "  make                  build the compiler"
	@echo "  make test             run test suite"
	@echo "  make hello            compile and run hello.ml"
	@echo "  make clean            remove build artifacts"
	@echo ""
	@echo "  ./loo file.byte        compile to Lua (no install needed)"
	@echo "  ./loo file.byte -o out  compile to out.lua"
