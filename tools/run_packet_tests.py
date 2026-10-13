#!/usr/bin/env python3
"""Golden Python CRC vectors -> real serial bits -> compiled C -> real replies."""
import json,os,subprocess,zlib,time,re
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1];out=ROOT/'build/packet';out.mkdir(parents=True,exist_ok=True)
def frame(seq,op,data):
 b=bytes([len(data),seq,op])+bytes(data);return b'\xa5'+b+zlib.crc32(b).to_bytes(4,'little')
# Byte pacing allows CPU service; the partial request is placed exactly at midpoint.
first=frame(1,1,[3,7,11])+frame(2,2,[255,1,2])+frame(2,2,[255,1,2])+frame(3,99,[])
bad=bytearray(frame(4,1,[10]));bad[-1]^=1
first+=bad+bytes([0xa5,33])+bytes([0xa5,4,5,1,7])
second=frame(6,1,list(range(32)))
# Pad before partial request so the testbench's midpoint pause follows it.
first=bytes(max(0,len(second)-len(first)))+first
second+=bytes(max(0,len(first)-len(second)))
inputs=first+second
expected=frame(1,0,[3,7,11])+frame(2,0,[258&255,1,0,0])+frame(2,3,[])+frame(3,2,[])+frame(6,0,list(range(32)))
(out/'input.hex').write_text(''.join(f'{b:02x}\n' for b in inputs));(out/'output.hex').write_text(''.join(f'{b:02x}\n' for b in expected))
rtl=['ft_pkg','riscue_pipeline_pkg','riscue_rvc','riscue_jump_target','riscue_execute','riscue_muldiv','riscue_pipeline_core','ft_ecc_ram','ft_event_monitor','riscue_packet_uart','riscue_packet_soc']
files=[str(ROOT/'rtl'/(n+'.sv')) for n in rtl]+[str(ROOT/'boards/kc705'/n) for n in ('uart_rx.sv','uart_tx.sv')]
symbols=subprocess.check_output([os.environ.get('RISCV_NM','riscv64-unknown-elf-nm'),str(out/'packet.elf')],text=True)
descriptor=int(re.search(r'^([0-9a-f]+)\s+\w\s+owner_inv$',symbols,re.M).group(1),16)
verilator=os.environ.get('VERILATOR','verilator');results=[]
for top,mode in [('tb_packet_uart',0),('tb_packet',0),('tb_packet',1)]:
 build=out/f'{top}-{mode}';label=f'{top}-{mode}';start=time.monotonic()
 args=[verilator,'--binary','--timing','--top-module',top,'-Wno-fatal','-j','2','--Mdir',str(build),*files,str(ROOT/'tests'/(top+'.sv'))]
 if top=='tb_packet':args.insert(1,f'-GRF_TMR={mode}')
 with (out/(label+'-compile.log')).open('w') as log:subprocess.run(args,cwd=ROOT,stdout=log,stderr=subprocess.STDOUT,check=True)
 for scenario in (['normal','ram_sec','ram_ded','descriptor_fault'] if top=='tb_packet' else ['unit']):
  case=label+'-'+scenario;args=[str(build/('V'+top))]
  if top=='tb_packet':args += [f'+inputs={len(inputs)}',f'+outputs={len(expected)}']
  if scenario!='normal' and scenario!='unit':args += ['+'+scenario,f'+descriptor_address={descriptor}']
  with (out/(case+'.log')).open('w') as log:subprocess.run(args,cwd=ROOT,stdout=log,stderr=subprocess.STDOUT,check=True,timeout=180)
  passes=[l for l in (out/(case+'.log')).read_text().splitlines() if l.startswith('PASS')]
  if len(passes)!=1:raise RuntimeError('Missing unique PASS: '+case)
  record={'test':case,'status':'pass','result':passes[0],'seconds':time.monotonic()-start};results.append(record);print(json.dumps(record),flush=True)
(out/'results.json').write_text(json.dumps(results,indent=2)+'\n')
