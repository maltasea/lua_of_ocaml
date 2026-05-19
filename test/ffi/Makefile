ROOT = ../..
LUA ?= lua
OCAMLC ?= ocamlc
DUNE ?= dune
OUT = test/_out/ffi

.PHONY: test roundtrip runtime clean

test: roundtrip runtime

roundtrip:
	(cd $(ROOT) && mkdir -p $(OUT))
	(cd $(ROOT) && $(OCAMLC) -c -o $(OUT)/lua_stubs.o test/ffi/lua_stubs.c)
	(cd $(ROOT) && $(OCAMLC) -g -custom -o $(OUT)/roundtrip.byte $(OUT)/lua_stubs.o test/ffi/roundtrip.ml)
	(cd $(ROOT) && $(DUNE) exec -- compiler/bin-lua_of_ocaml/main.exe -- $(OUT)/roundtrip.byte -o $(OUT)/roundtrip.lua)
	(cd $(ROOT) && $(LUA) -e 'dofile("test/ffi/external_impl.lua"); dofile("$(OUT)/roundtrip.lua")')

runtime:
	(cd $(ROOT) && $(LUA) test/ffi/ffi_test.lua)

clean:
	(cd $(ROOT) && rm -rf $(OUT))
	rm -f *.byte *.cmi *.cmo lua_stubs.o
