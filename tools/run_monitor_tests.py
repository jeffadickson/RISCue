#!/usr/bin/env python3
"""Compile and exercise physical UART packets, including an ELF upload and run."""
import json,os,shutil,subprocess,time
from pathlib import Path
from pipeline_config import configuration
from kc705_monitor import elf_words,frame
protection=configuration()
ROOT=Path(__file__).resolve().parents[1]
def main():
    out=ROOT/'build/monitor'/protection['pipeline_protection'];out.mkdir(parents=True,exist_ok=True)
    protocol_only=os.environ.get('MONITOR_PROTOCOL_ONLY')=='1'
    words=[];entry=0;finish=0
    if not protocol_only:
        image=ROOT/'build/c-smoke/smoke.elf';entry,words=elf_words(image.read_bytes(),4096)
        vectors=ROOT/'build/monitor-c';vectors.mkdir(exist_ok=True)
        (vectors/'load.hex').write_text(''.join(f'{int.from_bytes(frame(i&255,3,a,v),"little"):040x}\n' for i,(a,v) in enumerate(words)))
        (vectors/'golden.mask').write_text(''.join(('00000000' if 'x' in line.lower() else '00000001')+'\n' for line in (ROOT/'build/axi-c/smoke.expected').read_text().splitlines()))
        finish=json.loads((ROOT/'build/c-smoke/metadata.json').read_text())['finish_pc']
    rtl=['ft_pkg','riscue_pipeline_pkg','riscue_rvc','riscue_jump_target','riscue_execute','riscue_muldiv','riscue_pipeline_core','riscue_axi_master_bridge','riscue_axi_core','ft_ecc_ram','riscue_axi_ecc_ram','riscue_serial_monitor','riscue_monitor_soc']
    files=[str(ROOT/'rtl'/(name+'.sv')) for name in rtl]+[str(ROOT/p) for p in ('boards/kc705/uart_rx.sv','boards/kc705/uart_tx.sv','tests/tb_serial_monitor.sv')]
    results=[]
    rf_modes=(int(os.environ['MONITOR_RF']),) if 'MONITOR_RF' in os.environ else (0,1)
    for mode in rf_modes:
        build=Path(os.environ.get('RISCUE_MONITOR_BUILD_ROOT',str(ROOT/'build/vmonitor')))/protection['pipeline_protection']/str(mode)
        build.mkdir(parents=True,exist_ok=True)
        args=[os.environ.get('VERILATOR','verilator'),*protection['iverilog_flags'],'--cc','--main','--exe','--timing','--top-module','tb_serial_monitor','-Wno-fatal','-CFLAGS','-O0','-j','2','--Mdir',str(build),f'-GRF_TMR={mode}',*files]
        with (out/f'compile-{mode}.log').open('w') as log:
            subprocess.run(args,cwd=ROOT,stdout=log,stderr=subprocess.STDOUT,check=True)
            header=build/'Vtb_serial_monitor__pch.h'
            if header.exists():
                for suffix in ('fast','slow'):shutil.copyfile(header,build/(header.name+'.'+suffix))
            subprocess.run(['make','-C',str(build),'-f','Vtb_serial_monitor.mk','-j','2'],stdout=log,stderr=subprocess.STDOUT,check=True)
        for program in ((False,) if protocol_only else (False,True)):
            label=f'{"c-smoke" if program else "protocol"}-{mode}';logpath=out/(label+'.log');start=time.monotonic()
            args=[str(build/'Vtb_serial_monitor')]
            if program:args += ['+c_program',f'+count={len(words)}',f'+entry={entry}',f'+finish_pc={finish}']
            with logpath.open('w') as log:subprocess.run(args,cwd=ROOT,stdout=log,stderr=subprocess.STDOUT,check=True,timeout=180)
            passes=[line for line in logpath.read_text().splitlines() if line.startswith('PASS')]
            if len(passes)!=1:raise RuntimeError(f'No unique PASS in {logpath}')
            record={'name':label,'pipeline_protection':protection['pipeline_protection'],'status':'pass','result':passes[0],'seconds':time.monotonic()-start};results.append(record);print(json.dumps(record),flush=True)
    (out/'results.json').write_text(json.dumps(results,indent=2)+'\n')
if __name__=='__main__':main()
