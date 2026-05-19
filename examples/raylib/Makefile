LOO = ../../loo.sh
LUA ?= luajit

.PHONY: run clean

main.byte: main.ml raylib_stubs.c
	ocamlc -c raylib_stubs.c
	ocamlc -c main.ml
	ocamlc -custom -o main.byte raylib_stubs.o main.cmo

main.lua: main.byte
	$(LOO) main.byte -o _gen.lua
	cat ../../runtime/lua/*.lua rl_bindings.lua _gen.lua > main.lua
	@rm -f raylib_stubs.o main.cmi main.cmo _gen.lua

run: main.lua
	$(LUA) main.lua

clean:
	rm -f main.lua main.byte _gen.lua *.cmi *.cmo *.o
