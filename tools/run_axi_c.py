#!/usr/bin/env python3
"""Explicit native SV CPU/AXI/ECC endpoint integration tests for actual C images."""
import json,os,subprocess,time
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1];files=['ft_pkg','riscue_pipeline_pkg','riscue_rvc','riscue_jump_target','riscue_execute','riscue_muldiv','riscue_pipeline_core','riscue_axi_master_bridge','riscue_axi_core','ft_ecc_ram','riscue_axi_ecc_ram'];results=[]
def run(item):
    case,name,tmr=item
    output=ROOT/f'build/axi-c/{name}-{tmr}';log=output.with_suffix('.log');started=time.monotonic()
    subprocess.run([os.environ.get('IVERILOG','iverilog'),'-g2012','-s','tb_axi_ecc_system',f'-Ptb_axi_ecc_system.RF_TMR={tmr}',f'-Ptb_axi_ecc_system.CASE={case}',f'-Ptb_axi_ecc_system.IMAGE="build/axi-c/{name}.hex"',f'-Ptb_axi_ecc_system.GOLDEN="build/axi-c/{name}.expected"','-o',str(output),*[str(ROOT/'rtl'/(f+'.sv')) for f in files],str(ROOT/'tests/tb_axi_ecc_system.sv')],cwd=ROOT,check=True,stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
    with log.open('w') as dst:subprocess.run([os.environ.get('VVP','vvp'),str(output),'+finish_pc='+(ROOT/f'build/axi-c/{name}.finish').read_text()],cwd=ROOT,stdout=dst,stderr=subprocess.STDOUT,check=True,timeout=600)
    passes=[l for l in log.read_text().splitlines() if l.startswith('PASS')];assert len(passes)==1,log.read_text()
    r={'name':name,'RF_TMR':tmr,'status':'pass','result':passes[0],'seconds':time.monotonic()-started};print(json.dumps(r),flush=True);return r
jobs=[(case,name,tmr) for case,name in enumerate(('smoke','workload','fir')) for tmr in (0,1)]
with ThreadPoolExecutor(max_workers=2) as pool:results=list(pool.map(run,jobs))
(ROOT/'build/axi-c/results.json').write_text(json.dumps(results,indent=2)+'\n')
