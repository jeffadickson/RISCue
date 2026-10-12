IVERILOG ?= iverilog
VVP ?= vvp
RTL = rtl/ft_pkg.sv rtl/rv32_execute.sv rtl/rv32im_ft_core.sv rtl/ft_ecc_ram.sv rtl/ft_event_monitor.sv rtl/rv32im_ft_soc.sv
.PHONY: test clean
build:
	mkdir -p build
build/tb_ecc: $(RTL) tests/tb_ecc.sv | build
	$(IVERILOG) -g2012 -s tb_ecc -o $@ $(RTL) tests/tb_ecc.sv
build/tb_exec: $(RTL) tests/tb_exec.sv build/exec_vectors.txt | build
	$(IVERILOG) -g2012 -s tb_exec -o $@ $(RTL) tests/tb_exec.sv
build/exec_vectors.txt: tools/gen_vectors.py | build
	python3 tools/gen_vectors.py
build/tb_soc: $(RTL) tests/tb_soc.sv | build
	$(IVERILOG) -g2012 -s tb_soc -o $@ $(RTL) tests/tb_soc.sv
build/tb_fault: $(RTL) tests/tb_fault.sv | build
	$(IVERILOG) -g2012 -s tb_fault -o $@ $(RTL) tests/tb_fault.sv
build/tb_ram: $(RTL) tests/tb_ram.sv | build
	$(IVERILOG) -g2012 -s tb_ram -o $@ $(RTL) tests/tb_ram.sv
test: build/tb_ecc build/tb_exec build/tb_soc build/tb_fault build/tb_ram build/tb_trace
	$(VVP) build/tb_ecc
	$(VVP) build/tb_exec
	$(VVP) build/tb_soc
	$(VVP) build/tb_fault
	$(VVP) build/tb_ram
	$(VVP) build/tb_trace
clean:
	rm -rf build
build/program.hex: tools/gen_program.py tools/gen_vectors.py | build
	python3 tools/gen_program.py
build/tb_trace: $(RTL) tests/tb_trace.sv build/program.hex | build
	$(IVERILOG) -g2012 -s tb_trace -o $@ $(RTL) tests/tb_trace.sv
SV2V ?= sv2v
YOSYS ?= yosys
.PHONY: synth
build/rtl.v: $(RTL) | build
	$(SV2V) $(RTL) > $@
RF_MODE ?= ecc
synth: build/rtl.v
	$(YOSYS) -Q -p 'read_verilog build/rtl.v; hierarchy -check -top rv32im_ft_soc -chparam WORDS 16 -chparam RF_TMR $(if $(filter tmr,$(RF_MODE)),1,0); proc; setattr -set keep 1 t:$$adff t:$$dff t:rv32_execute; opt; memory_collect; check -assert; stat; write_json build/netlist.json' > build/synthesis.log 2>&1
	@tail -8 build/synthesis.log
	python3 tools/audit_netlist.py build/netlist.json $(RF_MODE)
PYTHON ?= python3
.PHONY: fetch upstream cocotb cocotb-ecc cocotb-tmr
fetch:
	$(PYTHON) tools/fetch_upstream.py
upstream: fetch
	$(PYTHON) tools/build_upstream.py
cocotb-ecc: upstream
	$(PYTHON) tools/run_cocotb.py ecc
cocotb-tmr: upstream
	$(PYTHON) tools/run_cocotb.py tmr
cocotb: cocotb-ecc cocotb-tmr
.PHONY: interfaces
interfaces:
	$(PYTHON) tools/run_interfaces.py ecc 0
	$(PYTHON) tools/run_interfaces.py tmr 0
	$(PYTHON) tools/run_interfaces.py ecc 1
	$(PYTHON) tools/run_interfaces.py tmr 1
cocotb: interfaces

.PHONY: synth-ecc synth-tmr
synth-ecc:
	$(MAKE) synth RF_MODE=ecc
synth-tmr:
	$(MAKE) synth RF_MODE=tmr

.PHONY: formal-tools formal-fetch formal-prepare formal formal-ecc formal-ram formal-monitor formal-fault formal-isa formal-execute
formal-tools:
	$(PYTHON) tools/setup_formal.py
formal-fetch:
	$(PYTHON) tools/fetch_upstream.py
formal-prepare: formal-fetch formal-tools
	$(PYTHON) tools/run_formal.py prepare
FORMAL_JOBS ?= 2
FORMAL_TIMEOUT ?= 300
FORMAL_ARGS = --jobs $(FORMAL_JOBS) --timeout $(FORMAL_TIMEOUT)

formal: formal-fetch formal-tools formal-model-tests
	$(PYTHON) tools/run_formal.py all $(FORMAL_ARGS)
formal-ecc formal-ram formal-monitor formal-fault formal-isa formal-execute: formal-fetch formal-tools
	$(PYTHON) tools/run_formal.py $(patsubst formal-%,%,$@) $(FORMAL_ARGS)

.PHONY: formal-model-tests
formal-model-tests: formal-fetch formal-tools
	$(PYTHON) tools/test_formal_models.py
