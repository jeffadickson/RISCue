"""Build and run the matched RISCue smoke fixture under Cocotb 2.x."""
import argparse
from pathlib import Path
from cocotb_tools.runner import get_runner

P=argparse.ArgumentParser()
P.add_argument("--sim",choices=["icarus","verilator"],required=True)
P.add_argument("--build-dir",required=True)
A=P.parse_args()
sources=["rtl/ft_pkg.sv","rtl/riscue_pipeline_pkg.sv","rtl/riscue_rvc.sv",
"rtl/riscue_jump_target.sv","rtl/riscue_execute.sv","rtl/riscue_muldiv.sv",
"rtl/riscue_pipeline_core.sv","rtl/ft_ecc_ram.sv","rtl/ft_event_monitor.sv",
"rtl/riscue_pipeline_soc.sv","tests/sharptestbench/tb_sharptestbench_riscue.sv"]
build=Path(A.build_dir).resolve()
build.mkdir(parents=True,exist_ok=True)
r=get_runner(A.sim)()
r.build(sources=[Path(s).resolve() for s in sources],hdl_toplevel="tb_sharptestbench_riscue",
build_dir=build,always=True,build_args=["-Wno-fatal"] if A.sim=="verilator" else [])
r.test(hdl_toplevel="tb_sharptestbench_riscue",
test_module="test_riscue_cocotb_smoke",
test_dir=build,
extra_env={"PYTHONPATH":str(Path("tests/sharptestbench").resolve()),
"RISCUE_COCOTB_TRACE":str(build/"cocotb-trace.json")})
