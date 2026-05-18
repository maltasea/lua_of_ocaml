.PHONY: test clean test-all

test:
	bash run_tests.sh

test-all:
	bash run_all.sh

clean:
	rm -f *.byte *.lua *.cmi *.cmo *.cma
	cd compiler && $(MAKE) clean
	cd runtime && $(MAKE) clean
	cd ffi && $(MAKE) clean
	cd smoke && $(MAKE) clean
