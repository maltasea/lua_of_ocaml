.PHONY: test clean

test:
	bash run_all.sh

clean:
	rm -rf _out
	rm -f *.byte *.cmi *.cmo *.cma
	cd compiler && $(MAKE) clean
	cd runtime && $(MAKE) clean
	cd ffi && $(MAKE) clean
	cd smoke && $(MAKE) clean
