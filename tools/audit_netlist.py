#!/usr/bin/env python3
"""Fail if generic synthesis has merged TMR storage or execution instances.
This checks logical storage separation; it does not certify physical independence.
"""
import json,sys
from pathlib import Path
d=json.loads(Path(sys.argv[1]).read_text());checked=[]
for name,m in d['modules'].items():
 for names in [('c0','c1','c2'),('s0','s1','s2'),('report0','report1','report2')]:
  if all(n in m['netnames'] for n in names):
   bits=[set(b for b in m['netnames'][n]['bits'] if isinstance(b,int)) for n in names]
   assert all(bits),f'{name}: missing register bits'
   for i in range(3):
    for j in range(i):assert not bits[i]&bits[j],f'{name}: merged {names[i]}/{names[j]}'
   # Every replica must be driven by its own actual sequential cell(s).
   drivers=[]
   for bs in bits:
    ds=set()
    for cell_name,cell in m['cells'].items():
     if cell['type'] in ('$adff','$adffe','$dff','$dffe','$sdff','$sdffe') and bs&set(cell['connections']['Q']):ds.add(cell_name)
    assert ds,f'{name}: no sequential driver for {names}'
    drivers.append(ds)
   for i in range(3):
    for j in range(i):assert not drivers[i]&drivers[j],f'{name}: shared sequential cell'
   checked.append((name,names))
 if all(n in m['cells'] for n in ['lane0','lane1']):
  assert m['cells']['lane0']['type']=='rv32_execute' and m['cells']['lane1']['type']=='rv32_execute'
  outs=[set(b for b in m['cells'][n]['connections']['out'] if isinstance(b,int)) for n in ['lane0','lane1']]
  assert not outs[0]&outs[1],f'{name}: merged execution outputs'
  checked.append((name,('lane0','lane1')))
assert len(checked)==4,f'Expected 4 redundancy groups, got {checked}'
# Optional RF TMR: each nonzero word must retain separate replica storage nets.
rf_words=0
for name,m in d['modules'].items():
 if 'rv32im_ft_core' not in name:continue
 for index in range(1,32):
  names=[f'tmr{r}[{index}]' for r in range(3)]
  if all(n in m['netnames'] for n in names):
   sets=[set(b for b in m['netnames'][n]['bits'] if isinstance(b,int)) for n in names]
   if not any(sets):continue
   assert all(sets),f'{name}: incomplete RF replicas at {index}'
   assert not (sets[0]&sets[1] or sets[0]&sets[2] or sets[1]&sets[2]),f'{name}: merged RF replicas at {index}'
   drivers=[]
   for bs in sets:
    ds={n for n,c in m['cells'].items() if c['type'] in ('$adff','$adffe','$dff','$dffe','$sdff','$sdffe') and bs&set(c['connections']['Q'])}
    assert ds,f'{name}: no RF sequential driver at {index}'
    drivers.append(ds)
   assert not (drivers[0]&drivers[1] or drivers[0]&drivers[2] or drivers[1]&drivers[2]),f'{name}: shared RF sequential driver at {index}'
   rf_words+=1
if len(sys.argv)>2 and sys.argv[2]=='tmr':assert rf_words==31,f'Expected 31 RF TMR words, found {rf_words}'
print('PASS netlist audit: CPU/RAM/reporter TMR, two execution instances, RF TMR words:',rf_words)
