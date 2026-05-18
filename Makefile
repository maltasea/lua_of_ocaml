.PHONY: build test clean hello run help

build:
	dune build

test:
	bash test/run_all.sh

clean:
	dune clean
	rm -rf test/_out
	find . -name '*.byte' -o -name '*.cmi' -o -name '*.cmo' -o -name '*.cma' | xargs rm -f

_hello.lua: hello.ml build
	ocamlc -g -o _hello.byte hello.ml
	dune exec -- compiler/bin-lua_of_ocaml/main.exe -- _hello.byte -o _hello.lua
	@rm -f _hello.byte _hello.cmi _hello.cmo

hello: _hello.lua
	lua _hello.lua
	@rm -f _hello.lua

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
