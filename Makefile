.PHONY: test wave clean

test:
	./scripts/run_verilator.sh

wave:
	gtkwave build/packet_fsm_tb.vcd

clean:
	rm -rf build
