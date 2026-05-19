LOO = ../loo.sh
LUA ?= luajit
LOVE ?= love

.PHONY: run clean

liblove_stubs.a: love_stubs.c
	ocamlc -c love_stubs.c
	ar rcs liblove_stubs.a love_stubs.o

main.byte: main.ml liblove_stubs.a
	ocamlc -c main.ml
	ocamlc -custom -o main.byte love_stubs.o main.cmo

main.lua: main.byte
	$(LOO) main.byte -o _gen.lua
	cat ../runtime/lua/*.lua love_runtime.lua _gen.lua > main.lua
	@rm -f love_stubs.o main.cmi main.cmo _gen.lua

run: main.lua conf.lua
	$(LOVE) .

clean:
	rm -f main.lua main.byte _gen.lua *.cmi *.cmo *.o *.a *.cma
