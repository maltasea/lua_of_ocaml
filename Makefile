LUA ?= luajit

.PHONY: build test clean hello run help

build: loo.sh
	dune build

loo.sh: misc/loo.in
	sed "s|@ROOT@|$(shell pwd)|" misc/loo.in > loo.sh
	chmod +x loo.sh

test:
	LUA=$(LUA) bash test/run_all.sh

clean:
	dune clean
	rm -rf test/_out
	rm -f hello* loo.sh
	find . -name '*.byte' -o -name '*.cmi' -o -name '*.cmo' -o -name '*.cma' | xargs rm -f

hello.ml:
	@echo 'let () = print_endline "hello from lua"' > hello.ml

hello: build hello.ml
	./loo.sh hello.ml -o hello.lua
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
	@echo "  ./loo.sh prog.ml            .ml or .byte -> Lua"
	@echo "  ./loo.sh prog.ml -o out.lua write to file"
