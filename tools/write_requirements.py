#!/usr/bin/env python3
"""Render the canonical requirements JSON without discarding new requirements."""
import csv,json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
rows=json.loads((ROOT/'docs/requirements.json').read_text())
with (ROOT/'docs/requirements.csv').open('w',newline='') as f:
 writer=csv.DictWriter(f,fieldnames=['id','category','requirement','verification','status','priority'])
 writer.writeheader();writer.writerows(rows)
text=['# Strict requirements and traceability — RISCue 0.7','',
 'Implemented describes available RTL/harnesses, not completed verification. Executed evidence is reported separately; open requirements remain open.','',
 '| ID | Requirement | Verification | Status |','| --- | --- | --- | --- |']
for row in rows:
 text.append('| '+' | '.join(str(row[k]).replace('|', '\\|') for k in ['id','requirement','verification','status'])+' |')
(ROOT/'docs/REQUIREMENTS.md').write_text('\n'.join(text)+'\n')
