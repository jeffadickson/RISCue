#!/usr/bin/env python3
"""Build pinned RV32IM test bodies and C workloads with a local bare-metal EEI."""
import json,os,subprocess,hashlib
from pathlib import Path
from software_profile import load_profile
from check_elf import check
ROOT=Path(__file__).resolve().parents[1];pipeline=os.environ.get('FT_PIPELINE')=='1';out=ROOT/('build/pipeline-upstream' if pipeline else 'build/upstream');out.mkdir(parents=True,exist_ok=True)
cc=os.environ.get('RISCV_GCC','riscv64-unknown-elf-gcc');objcopy=os.environ.get('RISCV_OBJCOPY','riscv64-unknown-elf-objcopy')
profile=load_profile()
common=(profile['compiler_flags'] if pipeline else ['-march=rv32im','-mabi=ilp32'])+['-nostdlib','-nostartfiles','-ffreestanding','-fno-builtin','-fno-pic','-msmall-data-limit=0','-Wl,--no-relax','-T',str(ROOT/'firmware/upstream/link.ld')]
records=[];tests=ROOT/'third_party/riscv-tests';pico=ROOT/'third_party/picorv32'
if not tests.exists() or not pico.exists():raise SystemExit('Run make fetch first.')
for repo,item in json.loads((ROOT/'upstream.lock.json').read_text()).items():
 actual=subprocess.check_output(['git','-C',str(ROOT/'third_party'/repo),'rev-parse','HEAD'],text=True).strip()
 if actual!=item['commit']:raise SystemExit(f'{repo}: commit does not match lock')
 if subprocess.check_output(['git','-C',str(ROOT/'third_party'/repo),'status','--porcelain'],text=True).strip():raise SystemExit(f'{repo}: dirty source')
def build(name,sources,opts=(),budget=30000):
 elf=out/(name+'.elf');binary=out/(name+'.bin')
 cmd=[cc,*common,*opts,*map(str,sources),'-o',str(elf)]
 r=subprocess.run(cmd,text=True,stdout=subprocess.PIPE,stderr=subprocess.STDOUT)
 if r.returncode:raise RuntimeError(name+'\n'+r.stdout)
 if pipeline:check(elf,profile,os.environ.get('RISCV_READELF','riscv64-unknown-elf-readelf'),os.environ.get('RISCV_OBJDUMP','riscv64-unknown-elf-objdump'))
 subprocess.run([objcopy,'-O','binary',str(elf),str(binary)],check=True)
 data=binary.read_bytes()
 if len(data)>0x7000:raise RuntimeError(name+' image too large')
 records.append({'name':name,'binary':str(binary.relative_to(ROOT)), 'sha256':hashlib.sha256(data).hexdigest(),'max_cycles':budget,'pass_register':10,'pass_value':0})
for suite in (['rv32ui','rv32um','rv32uc'] if pipeline else ['rv32ui','rv32um']):
 for src in sorted((tests/'isa'/suite).glob('*.S')):
  if src.stem=='ma_data' or (src.stem=='fence_i' and not pipeline):continue
  build(suite+'-'+src.stem,[src],['-I'+str(ROOT/'firmware/upstream'),'-I'+str(tests/'isa/macros/scalar')])
start=ROOT/'firmware/upstream/start.S'
build('sieve',[start,pico/'firmware/sieve.c',ROOT/'firmware/upstream/sieve_port.c'],['-O2','-I'+str(pico/'firmware')],120000)
# Original source bodies stay unchanged; only main is renamed in compiled object.
dhry_opts=['-O2','-std=gnu89','-DTIME','-DRISCV','-DUSE_MYSTDLIB','-I'+str(pico/'dhrystone')]
obj=out/'dhry_1.o'
subprocess.run([cc,*(profile['compiler_flags'] if pipeline else ['-march=rv32im','-mabi=ilp32']),'-ffreestanding','-fno-builtin','-msmall-data-limit=0',*dhry_opts,'-Dmain=dhry_main','-c',str(pico/'dhrystone/dhry_1.c'),'-o',str(obj)],check=True,stdout=subprocess.DEVNULL)
build('dhrystone',[start,obj,pico/'dhrystone/dhry_2.c',ROOT/'firmware/upstream/dhry_port.c'],dhry_opts,300000)
manifest={'source_lock':json.loads((ROOT/'upstream.lock.json').read_text()),'programs':records,'excluded':{**({} if pipeline else {'rv32ui-fence_i':'Zifencei is not implemented'}),'rv32ui-ma_data':'test expects misaligned-access handling not supplied by external EEI'}}
(out/'manifest.json').write_text(json.dumps(manifest,indent=2))
print('Built',len(records),'pinned upstream programs')
