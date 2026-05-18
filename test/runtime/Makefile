ROOT = ../..

.PHONY: test clean

test:
	(cd $(ROOT) && lua test/runtime/ints_test.lua)
	(cd $(ROOT) && lua test/runtime/string_test.lua)
	(cd $(ROOT) && lua test/runtime/obj_test.lua)

clean:
	rm -f *.byte *.lua *.cmi *.cmo
