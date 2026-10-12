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

# Board builds are explicit and never run simulation or formal verification.
VIVADO ?= vivado
KC705_FI ?= 0
KC705_INSTRUMENTED ?= 0
KC705_WORDS ?= 1024
KC705_CLK_DIV ?= 100
KC705_IMAGE ?= firmware/kc705/demo.hex
KC705_BUILD = build/kc705-pipeline-$(RF_MODE)-fi$(KC705_FI)-d$(KC705_CLK_DIV)$(if $(filter 1,$(KC705_INSTRUMENTED)),-instrumented,)
.PHONY: kc705-image kc705 kc705-synth kc705-program
kc705-image:
	$(PYTHON) tools/prepare_fpga_image.py "$(KC705_IMAGE)" "$(KC705_BUILD)/firmware.hex" --words $(KC705_WORDS)
kc705: kc705-image
	$(VIVADO) -mode batch -nojournal -log "$(KC705_BUILD)/vivado.log" -source boards/kc705/build.tcl -tclargs "$(KC705_BUILD)" $(if $(filter tmr,$(RF_MODE)),1,0) $(KC705_FI) $(KC705_WORDS) $(KC705_CLK_DIV) bit $(KC705_INSTRUMENTED)
kc705-synth: kc705-image
	$(VIVADO) -mode batch -nojournal -log "$(KC705_BUILD)/vivado.log" -source boards/kc705/build.tcl -tclargs "$(KC705_BUILD)" $(if $(filter tmr,$(RF_MODE)),1,0) $(KC705_FI) $(KC705_WORDS) $(KC705_CLK_DIV) synth $(KC705_INSTRUMENTED)
kc705-program:
	$(VIVADO) -mode batch -nojournal -log "$(KC705_BUILD)/program.log" -source boards/kc705/program.tcl -tclargs "$(KC705_BUILD)/riscue_kc705.bit"

# New pipeline targets are explicit; test/formal retain legacy evidence scope.
PIPELINE_RTL = rtl/ft_pkg.sv rtl/riscue_pipeline_pkg.sv rtl/riscue_rvc.sv rtl/riscue_execute.sv rtl/riscue_muldiv.sv rtl/riscue_pipeline_core.sv rtl/ft_ecc_ram.sv rtl/ft_event_monitor.sv rtl/riscue_pipeline_soc.sv
.PHONY: pipeline-compile pipeline-test pipeline-test-ecc pipeline-test-tmr formal-pipeline formal-pipeline-prepare kc705-instrumented kc705-instrumented-synth kc705-inject test-muldiv test-injector
pipeline-compile: | build
	$(IVERILOG) -g2012 -s tb_pipeline -o build/pipeline_compile $(PIPELINE_RTL) tests/cocotb/tb_pipeline.sv
pipeline-test-ecc: pipeline-tools
	$(PIPELINE_PYTHON) tools/run_pipeline.py ecc
pipeline-test-tmr: pipeline-tools
	$(PIPELINE_PYTHON) tools/run_pipeline.py tmr
pipeline-test: pipeline-test-ecc pipeline-test-tmr
formal-pipeline formal-pipeline-prepare: formal-fetch formal-tools
	$(PYTHON) tools/run_formal.py $(patsubst formal-%,%,$@) $(FORMAL_ARGS)
kc705-instrumented:
	$(MAKE) kc705 KC705_FI=1 KC705_INSTRUMENTED=1
kc705-instrumented-synth:
	$(MAKE) kc705-synth KC705_FI=1 KC705_INSTRUMENTED=1
KC705_INJECT_TARGET ?= 8
KC705_INJECT_INDEX ?= 1023
KC705_INJECT_MASK ?= 1
kc705-inject:
	$(MAKE) kc705-inject-run KC705_FI=1 KC705_INSTRUMENTED=1
.PHONY: kc705-inject-run
kc705-inject-run:
	$(VIVADO) -mode batch -nojournal -source boards/kc705/lab/run_injection.tcl -tclargs "$(KC705_BUILD)" $(KC705_INJECT_TARGET) $(KC705_INJECT_INDEX) $(KC705_INJECT_MASK)
test-muldiv: | build
	$(IVERILOG) -g2012 -s tb_muldiv -o build/tb_muldiv rtl/ft_pkg.sv rtl/riscue_pipeline_pkg.sv rtl/riscue_muldiv.sv tests/tb_muldiv.sv
	$(VVP) build/tb_muldiv
test-injector: | build
	$(IVERILOG) -g2012 -s tb_injector -o build/tb_injector rtl/ft_pkg.sv rtl/riscue_pipeline_pkg.sv rtl/fi_campaign_controller.sv tests/tb_injector.sv
	$(VVP) build/tb_injector

.PHONY: pipeline-upstream-build pipeline-upstream
pipeline-upstream-build: fetch
	FT_PIPELINE=1 $(PYTHON) tools/build_upstream.py
pipeline-upstream: pipeline-tools pipeline-upstream-build
	$(PIPELINE_PYTHON) tools/run_pipeline.py ecc --upstream
	$(PIPELINE_PYTHON) tools/run_pipeline.py tmr --upstream

PIPELINE_PYTHON ?= .tools/test-python/bin/python
.PHONY: pipeline-tools
pipeline-tools: formal-tools
	$(PYTHON) tools/setup_testing.py

.PHONY: formal-muldiv formal-injector
formal-muldiv formal-injector: formal-fetch formal-tools
	$(PYTHON) tools/run_formal.py $(patsubst formal-%,%,$@) $(FORMAL_ARGS)
