"""Build cached standalone Verilator simulations with source/tool provenance."""
import hashlib,json,os,shutil,signal,subprocess,time
from pathlib import Path
def build_verilator(root,tb,rtl,flags,label,log,timeout=600):
 root=Path(root);tb=Path(tb);verilator=shutil.which('verilator') or '/opt/verilator-5.048/bin/verilator'
 sources=[root/'rtl'/(name+'.sv') for name in rtl]+[tb]
 manifest={'sources':{str(p.relative_to(root)):hashlib.sha256(p.read_bytes()).hexdigest() for p in sources},'flags':flags,'verilator_version':subprocess.check_output([verilator,'--version'],text=True).strip()}
 core_hash=hashlib.sha256((root/'rtl/riscue_pipeline_core.sv').read_bytes()).hexdigest()[:12]
 cache=Path.home()/'.cache/riscue-design-bench'/core_hash/label;cache.mkdir(parents=True,exist_ok=True)
 record=cache/'source-manifest.json';top=tb.stem;exe=cache/('V'+top)
 if exe.exists() and record.exists() and json.loads(record.read_text())==manifest:return exe,manifest
 def run(cmd,f):
  p=subprocess.Popen(cmd,cwd=root,stdout=f,stderr=subprocess.STDOUT,start_new_session=True)
  try:code=p.wait(timeout=timeout)
  except subprocess.TimeoutExpired:os.killpg(p.pid,signal.SIGKILL);p.wait();raise
  if code:raise RuntimeError(str(cmd[0])+' failed: '+str(log))
 with Path(log).open('w') as f:
  run([verilator,*flags,'--cc','--main','--exe','--timing','-Wno-fatal','--top-module',top,'--Mdir',str(cache),*[str(p) for p in sources]],f)
  header=cache/('V'+top+'__pch.h')
  if header.exists():
   for suffix in ('fast','slow'):shutil.copyfile(header,cache/(header.name+'.'+suffix))
  run(['make','-C',str(cache),'-f','V'+top+'.mk','-j','2'],f)
 record.write_text(json.dumps(manifest,indent=2)+'\n')
 return exe,manifest
