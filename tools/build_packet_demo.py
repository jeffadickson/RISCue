#!/usr/bin/env python3
"""Compile and simulate the CRC example, then embed its real trace in HTML."""
import base64,binascii,csv,hashlib,html,json,os,re,shutil,subprocess
from pathlib import Path
from pipeline_config import configuration
from software_profile import load_profile
from check_elf import check

ROOT=Path(__file__).resolve().parents[1]

def main():
 config=configuration();profile=load_profile();out=ROOT/'build/packet-demo'/config['pipeline_protection'];out.mkdir(parents=True,exist_ok=True)
 tools=ROOT/'.tools/riscv/root/usr/bin';cc=shutil.which('riscv64-unknown-elf-gcc') or str(tools/'riscv64-unknown-elf-gcc')
 if not Path(cc).exists():raise SystemExit('Run make c-tools in Ubuntu first')
 prefix=str(Path(cc).parent/'riscv64-unknown-elf-')
 elf=out/'packet.elf';binary=out/'packet.bin'
 command=[cc,*profile['compiler_flags'],'-O2','-Wall','-Wextra','-Werror','-nostdlib','-nostartfiles','-Wl,--no-relax','-T',str(ROOT/'firmware/smoke/link.ld'),str(ROOT/'firmware/smoke/start.S'),str(ROOT/'firmware/packet-demo/main.c'),str(ROOT/'firmware/packet-demo/crc16.S'),'-o',str(elf)]
 compiler_command=command.copy()
 with (out/'compiler.log').open('w') as log:subprocess.run(command,stdout=log,stderr=subprocess.STDOUT,check=True)
 audit=check(elf,profile,prefix+'readelf',prefix+'objdump');subprocess.run([prefix+'objcopy','-O','binary',str(elf),str(binary)],check=True)
 syms=subprocess.check_output([prefix+'nm',str(elf)],text=True)
 finish=int(re.search(r'^([0-9a-fA-F]+)\s+\w\s+_finished$',syms,re.M).group(1),16)
 crc_pc=int(re.search(r'^([0-9a-fA-F]+)\s+\w\s+crc16_packet$',syms,re.M).group(1),16)
 listing=subprocess.check_output([prefix+'objdump','-d',str(elf)],text=True);(out/'packet.dis').write_text(listing)
 image=binary.read_bytes();assert len(image)<=4096
 image=image.ljust(4096,b'\0');image_path=out/'program.hex';image_path.write_text(''.join(f'{int.from_bytes(image[i:i+4],"little"):08x}\n' for i in range(0,len(image),4)))
 build=Path(os.environ.get('RISCUE_DEMO_BUILD_ROOT',str(Path.home()/'.cache/riscue-packet-demo')))/config['pipeline_protection'];build.mkdir(parents=True,exist_ok=True)
 rtl='ft_pkg riscue_pipeline_pkg riscue_rvc riscue_jump_target riscue_execute riscue_muldiv riscue_pipeline_core ft_ecc_ram ft_event_monitor riscue_pipeline_soc'.split()
 command=[os.environ.get('VERILATOR','verilator'),*config['iverilog_flags'],'--cc','--main','--exe','--timing','--trace','--trace-depth','1','-Wno-fatal','--top-module','tb_packet_demo','--Mdir',str(build),*[str(ROOT/'rtl'/(n+'.sv')) for n in rtl],str(ROOT/'tests/tb_packet_demo.sv')]
 with (out/'build.log').open('w') as log:
  subprocess.run(command,stdout=log,stderr=subprocess.STDOUT,check=True)
  header=build/'Vtb_packet_demo__pch.h'
  if header.exists():
   for suffix in ('fast','slow'):shutil.copyfile(header,build/(header.name+'.'+suffix))
  subprocess.run(['make','-C',str(build),'-f','Vtb_packet_demo.mk','-j','2'],stdout=log,stderr=subprocess.STDOUT,check=True)
 packet_crc=binascii.crc_hqx(bytes([0x10,0x20,0x00,0xff,0x7e,0x81]),0xffff)
 run=subprocess.run([str(build/'Vtb_packet_demo'),f'+image={image_path}',f'+trace={out/"trace.csv"}',f'+wave={out/"pipeline.vcd"}',f'+finish={finish}',f'+packet_crc={packet_crc}'],cwd=ROOT,capture_output=True,text=True,timeout=120)
 (out/'run.log').write_text(run.stdout+run.stderr);assert run.returncode==0 and 'PASS packet CRC assembly' in run.stdout and 'Assertion failed' not in run.stdout+run.stderr,run.stdout+run.stderr
 assert (out/'pipeline.vcd').stat().st_size>0
 with (out/'trace.csv').open() as f:
  reader=csv.reader(f);columns=next(reader);hex_fields={'pc','fpc','dpc','xpc','mpc','wpc','rpc','insn','result'}
  records=[[int(v,16 if k in hex_fields else 10) for k,v in zip(columns,row)] for row in reader]
 meta={'passed':True,'configuration':config,'compiler':subprocess.check_output([cc,'--version'],text=True).splitlines()[0],'compiler_command':compiler_command,'isa_audit':audit,'binary_sha256':hashlib.sha256(binary.read_bytes()).hexdigest(),'assembly_sha256':hashlib.sha256((ROOT/'firmware/packet-demo/crc16.S').read_bytes()).hexdigest(),'check_crc':0x29b1,'empty_crc':0xffff,'packet_crc':packet_crc,'cycles':len(records),'retirements':sum(row[12] for row in records),'crc_pc':crc_pc,'result':run.stdout}
 (out/'results.json').write_text(json.dumps(meta,indent=2)+'\n')
 payload={'metadata':meta,'columns':columns,'records':records,'vcd_base64':base64.b64encode((out/'pipeline.vcd').read_bytes()).decode()}
 template=(ROOT/'docs/templates/packet-processor-david.html').read_text(encoding='utf-8')
 document=template.replace('__DEMO_JSON__',json.dumps(payload,separators=(',',':')).replace('</','<\\/')).replace('__ASSEMBLY__',html.escape((ROOT/'firmware/packet-demo/crc16.S').read_text()))
 (out/'heres-your-packet-processor-david.html').write_text(document,encoding='utf-8')
 print(run.stdout);print('HTML:',out/'heres-your-packet-processor-david.html')

if __name__=='__main__':main()
