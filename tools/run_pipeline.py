#!/usr/bin/env python3
"""Explicit pipeline cocotb target; never invoked by board builds."""
import os,sys,xml.etree.ElementTree as ET
from pathlib import Path
from cocotb_tools.runner import get_runner,get_results
ROOT=Path(__file__).resolve().parents[1]
suite=ROOT/'.tools/oss-cad-suite/bin'
if suite.exists():os.environ['PATH']=str(suite)+os.pathsep+os.environ['PATH']
mode=sys.argv[1] if len(sys.argv)>1 else 'ecc'
if mode not in ('ecc','tmr'):raise SystemExit('Mode must be ecc or tmr')
upstream='--upstream' in sys.argv[2:]
workload='--c-workload' in sys.argv[2:]
early_jump='--late-jump' not in sys.argv[2:]
build=ROOT/'build'/('pipeline_'+mode+('_upstream' if upstream else '')+('_late_jump' if not early_jump else '')+('_c_workload' if workload else ''))
rtl=['ft_pkg.sv','riscue_pipeline_pkg.sv','riscue_rvc.sv','riscue_jump_target.sv','riscue_execute.sv','riscue_muldiv.sv','riscue_pipeline_core.sv','ft_ecc_ram.sv','ft_event_monitor.sv','riscue_pipeline_soc.sv']
runner=get_runner('icarus')
runner.build(sources=[ROOT/'rtl'/n for n in rtl]+[ROOT/'tests/cocotb/tb_pipeline.sv'],hdl_toplevel='tb_pipeline',parameters={'RF_TMR':int(mode=='tmr'),'WORDS':8192 if upstream else 2048 if workload else 1024,'EARLY_JUMP':int(early_jump)},build_args=['-g2012'],timescale=('1ns','1ps'),build_dir=build,always=True)
xml=runner.test(hdl_toplevel='tb_pipeline',test_module='test_pipeline',test_dir=ROOT/'tests/cocotb',build_dir=build,extra_env={'RF_TMR':str(int(mode=='tmr')),'PROJECT_ROOT':str(ROOT),'PIPELINE_UPSTREAM':str(int(upstream)),'EARLY_JUMP':str(int(early_jump)),'PIPELINE_C_WORKLOAD':str(int(workload))},test_filter='pinned_upstream_programs' if upstream else os.environ.get('TEST_FILTER'),results_xml=str(build/'results.xml'))
count,failed=get_results(xml);skipped=len(ET.parse(xml).findall('.//skipped'));print('pipeline',mode,count-skipped,'executed;',skipped,'skipped;',failed,'failed')
raise SystemExit(bool(failed))
