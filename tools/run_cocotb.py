#!/usr/bin/env python3
import os,sys,json,xml.etree.ElementTree as ET
from pathlib import Path
from cocotb_tools.runner import get_runner,get_results
ROOT=Path(__file__).resolve().parents[1]
mode=sys.argv[1] if len(sys.argv)>1 else 'ecc';tmr=mode=='tmr'
if mode not in ['ecc','tmr']:raise SystemExit('Mode must be ecc or tmr')
runner=get_runner('icarus')
sources=[ROOT/'rtl'/n for n in ['ft_pkg.sv','rv32_execute.sv','rv32im_ft_core.sv','ft_ecc_ram.sv','ft_event_monitor.sv','rv32im_ft_soc.sv']]+[ROOT/'tests/cocotb/tb_python.sv']
build=ROOT/'build'/('cocotb_'+mode)
runner.build(sources=sources,hdl_toplevel='tb_python',parameters={'RF_TMR':int(tmr)},build_dir=build,build_args=['-g2012'],timescale=('1ns','1ps'),always=True)
xml=runner.test(hdl_toplevel='tb_python',test_module='test_ft',test_dir=ROOT/'tests/cocotb',build_dir=build,extra_env={'PROJECT_ROOT':str(ROOT),'RF_TMR':str(int(tmr))},test_filter=os.environ.get('TEST_FILTER'),results_xml=str(build/(('control_results.xml') if os.environ.get('TEST_FILTER') else 'results.xml')))
count,failed=get_results(xml);skipped=len(ET.parse(xml).findall('.//skipped'));print('cocotb',mode,count-skipped,'executed,',skipped,'skipped,',failed,'failed')
raise SystemExit(bool(failed))
