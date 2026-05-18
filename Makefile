.PHONY: build test clean hello run help

build:
	dune build

test:
	bash test/run_tests.sh

clean:
	dune clean
	find . -name '*.byte' -o -name '*.cmi' -o -name '*.cmo' -o -name '*.cma' | xargs rm -f
	rm -f test/_*.ml test/_*.lua test/_*.byte

hello: build
	ocamlc -g -o test/hello.byte test/hello.ml
	dune exec -- compiler/bin-lua_of_ocaml/main.exe -- test/hello.byte -o test/hello.lua
	lua test/hello.lua

run: build
	dune exec -- compiler/bin-lua_of_ocaml/main.exe -- $(FILE)

help:
	@echo "lua_of_ocaml - OCaml to Lua 5.1 compiler"
	@echo ""
	@echo "  make           build the compiler"
	@echo "  make test      run test suite"
	@echo "  make hello     compile and run hello.ml"
	@echo "  make run FILE=my.byte   compile a bytecode file"
	@echo "  make clean     remove build artifacts"
