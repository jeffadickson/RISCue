#!/usr/bin/env python3
"""Elaborate KC705 debug wrapper with vendor stubs; no physical timing claim."""
import os,shutil,subprocess,json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
tool=os.environ.get('VERILATOR') or shutil.which('verilator') or str(ROOT/'.tools/monitor-verilator/verilator')
names='ft_pkg riscue_pipeline_pkg riscue_rvc riscue_jump_target riscue_execute riscue_muldiv riscue_pipeline_core ft_ecc_ram riscue_jtag_dtm riscue_debug_module riscue_debug_soc'.split()
out=ROOT/'build/debug';out.mkdir(parents=True,exist_ok=True)
for mode in (0,1):
 cmd=[tool,'--lint-only','--timing','-Wno-fatal','--top-module','riscue_kc705_debug',f'-GRF_TMR={mode}']+[str(ROOT/'rtl'/(n+'.sv')) for n in names]+[str(ROOT/'boards/kc705/debug/top.sv'),str(ROOT/'tests/kc705_vendor_stubs.sv')]
 with (out/f'kc705-lint-{mode}.log').open('w') as log:subprocess.run(cmd,stdout=log,stderr=subprocess.STDOUT,check=True)
 print('PASS KC705 debug stub elaboration RF_TMR=',mode)
(ROOT/'verification/debug-board.json').write_text(json.dumps({'elaboration_passed':True,'modes':[0,1],'vendor_primitives':'nonphysical stubs','vivado_implementation_run':False,'physical_board_run':False},indent=2)+'\n')
