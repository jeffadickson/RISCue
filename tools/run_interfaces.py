#!/usr/bin/env python3
import os,sys
from pathlib import Path
from cocotb_tools.runner import get_runner,get_results
ROOT=Path(__file__).resolve().parents[1];mode=sys.argv[1];fi=int(sys.argv[2]);tmr=int(mode=='tmr')
runner=get_runner('icarus');build=ROOT/'build'/f'interfaces_{mode}_{fi}'
sources=[ROOT/'rtl'/n for n in ['ft_pkg.sv','rv32_execute.sv','rv32im_ft_core.sv','ft_ecc_ram.sv','ft_event_monitor.sv','rv32im_ft_soc.sv']]+[ROOT/'tests/cocotb/tb_python.sv']
runner.build(sources=sources,hdl_toplevel='tb_python',parameters={'RF_TMR':tmr,'FI_ENABLE':fi},build_dir=build,build_args=['-g2012'],timescale=('1ns','1ps'),always=True)
xml=runner.test(hdl_toplevel='tb_python',test_module='test_interfaces',test_dir=ROOT/'tests/cocotb',build_dir=build,extra_env={'PROJECT_ROOT':str(ROOT),'RF_TMR':str(tmr),'FI_ENABLE':str(fi)},results_xml=str(build/'results.xml'))
count,failed=get_results(xml);print('interfaces',mode,fi,count,failed);raise SystemExit(bool(failed))
