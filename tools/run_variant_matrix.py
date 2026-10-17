#!/usr/bin/env python3
"""Required local regression gate; sequential builds avoid shared-output races."""
import hashlib,json,subprocess,time
from pathlib import Path
r=Path(__file__).resolve().parents[1]
out=r/'build'/'variant-matrix';out.mkdir(parents=True,exist_ok=True)
results=[]
commands=[['make','pipeline-selection-test']]+[['make','pipeline-smoke','pipeline-jump','PIPELINE_PROTECTION='+m,'ALLOW_EXPERIMENTAL_PARITY='+e] for m,e in [('TMR','0'),('PARITY_REPLAY','1'),('PLAIN','0')]]+[['make','pipeline-replay-test']]+[['make','docs','docs-check']]
for i,cmd in enumerate(commands):
 start=time.time();log=out/(str(i)+'.log')
 print('RUN',' '.join(cmd),flush=True)
 with log.open('w') as f: p=subprocess.run(cmd,cwd=r,stdout=f,stderr=subprocess.STDOUT,timeout=900)
 results.append({'command':cmd,'exit_code':p.returncode,'seconds':round(time.time()-start,2),'log':str(log.relative_to(r))})
 print(log.read_text()[-2200:],flush=True)
 (out/'results.json').write_text(json.dumps({'core_sha256':hashlib.sha256((r/'rtl/riscue_pipeline_core.sv').read_bytes()).hexdigest(),'results':results},indent=2)+'\n')
 if p.returncode:raise SystemExit(p.returncode)
print('PASS all three pipeline variants and protection/documentation gates')
