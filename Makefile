LUA ?= luajit
PREFIX ?= /usr/local

.PHONY: build test clean hello run install help html prim-inventory

build: loo.sh
	dune build

loo.sh: misc/loo.in
	sed -e "s|@LOO_BIN@|$(shell pwd)/_build/default/compiler/bin-lua_of_ocaml/main.exe|" \
	    -e "s|@RUNTIME@|$(shell pwd)/runtime/lua|" \
	    misc/loo.in > loo.sh
	chmod +x loo.sh

test:
	LUA=$(LUA) bash test/run_all.sh

clean:
	dune clean
	rm -rf test/_out
	rm -f hello* loo.sh index.html style.css
	find . -name '*.byte' -o -name '*.cmi' -o -name '*.cmo' -o -name '*.cma' | xargs rm -f

hello.ml:
	@echo 'let () = print_endline "hello from lua"' > hello.ml

hello: build hello.ml
	./loo.sh hello.ml -o hello.lua
	$(LUA) hello.lua

install: build
	install -d $(PREFIX)/bin $(PREFIX)/share/lua_of_ocaml/runtime/lua
	install -m 0755 _build/default/compiler/bin-lua_of_ocaml/main.exe \
	    $(PREFIX)/bin/lua_of_ocaml
	sed -e "s|@LOO_BIN@|$(PREFIX)/bin/lua_of_ocaml|" \
	    -e "s|@RUNTIME@|$(PREFIX)/share/lua_of_ocaml/runtime/lua|" \
	    misc/loo.in > $(PREFIX)/bin/loo
	chmod +x $(PREFIX)/bin/loo
	cp runtime/lua/*.lua $(PREFIX)/share/lua_of_ocaml/runtime/lua/

html: README.md
	rm -f style.css
	cp ~/work/site_template/style.css style.css
	pandoc README.md --standalone --metadata title="loo — lua_of_ocaml" --toc --css=style.css -o index.html

run: build
	dune exec -- compiler/bin-lua_of_ocaml/main.exe -- $(FILE)

prim-inventory: build
	@./misc/prim_inventory.sh

help:
	@echo "lua_of_ocaml - OCaml to Lua 5.1 compiler"
	@echo ""
	@echo "  make                  build the compiler"
	@echo "  make test             run test suite"
	@echo "  make hello            compile and run hello.ml"
	@echo "  make prim-inventory   audit primitive coverage in generated Lua"
	@echo "  make install          install to $$PREFIX ($(PREFIX))"
	@echo "  make clean            remove build artifacts"
	@echo ""
	@echo "  ./loo.sh prog.ml            .ml or .byte -> Lua"
	@echo "  ./loo.sh prog.ml -o out.lua write to file"
