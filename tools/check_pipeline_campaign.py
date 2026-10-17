#!/usr/bin/env python3
"""Directed simulation campaign, not exhaustive physical fault coverage."""
import argparse,itertools,subprocess,sys
from pathlib import Path
r=Path(__file__).resolve().parents[1]
p=argparse.ArgumentParser();p.add_argument('group',choices=['controller','commit','final']);a=p.parse_args()
legal=[0,7,25,30]
assert min((x^y).bit_count() for x,y in itertools.combinations(legal,2))>=3
cases=[]
if a.group=='controller':
 cases=[(8,rf,1) for rf in (0,1)]+[(9,0,1)]+[(3,0,code) for code in range(32) if code not in legal]
elif a.group=='commit':cases=[(scenario,rf,1) for scenario in (1,2,7,10,11) for rf in (0,1)]
else:cases=[(scenario,rf,1) for scenario in range(12) for rf in (0,1)]
for scenario,rf,code in cases:
 subprocess.run([sys.executable,str(r/'tools/check_pipeline_replay.py'),'--scenario',str(scenario),'--rf',str(rf),'--illegal',str(code)],check=True)
print(f'PASS {a.group}: {len(cases)} directed cases; recovery code distance >=3')
