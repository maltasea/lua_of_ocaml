ROOT = ../..

.PHONY: test clean

test:
	(cd $(ROOT) && lua test/ffi/ffi_test.lua)

clean:
	rm -f *.byte *.cmi *.cmo lu_stubs.o
