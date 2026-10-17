#!/usr/bin/env python3
"""Check mapped core replica bits are distinct; no placement or coverage proof."""
import itertools,json,re,sys
from pathlib import Path

def audit(netlist,parity=False):
 design=json.loads(Path(netlist).read_text());found=[]
 for module_name,module in design['modules'].items():
  qbits={bit for cell in module.get('cells',{}).values() if cell['type'].startswith('FD') for bit in cell['connections'].get('Q',[]) if isinstance(bit,int)}
  nets=module.get('netnames',{})
  for name in nets:
   match=re.fullmatch(r'(.*?)(?:^|[./])c0',name)
   if not match and name!='c0':continue
   prefix=name[:-2];group={}
   for replica in range(3):
    net=nets.get(prefix+'c'+str(replica));assert net is not None,'Missing core replica net'
    group[str(replica)]={bit for bit in net['bits'] if isinstance(bit,int)}&qbits
   assert all(group.values()),'Mapped core replica has no retained flip-flops'
   for a,b in itertools.combinations(group,2):assert not group[a]&group[b],f'Merged core state replicas {a}/{b}'
   counts={k:len(v) for k,v in group.items()}
   assert counts['1']==counts['2'],'Trusted replica sizes differ'
   if not parity:assert len(set(counts.values()))==1,'TMR core replica sizes differ'
   record={'module':module_name,'prefix':prefix,'core_replica_ff_bits':counts,'pairwise_disjoint':True}
   if parity:
    recovery={}
    for replica in range(3):
     net=nets.get(prefix+'replay'+str(replica));assert net is not None,'Missing recovery replica'
     recovery[str(replica)]={bit for bit in net['bits'] if isinstance(bit,int)}&qbits
    assert all(recovery.values()),'Recovery controller was optimized away'
    for a,b in itertools.combinations(recovery,2):assert not recovery[a]&recovery[b],'Merged recovery replicas'
    record['recovery_replica_ff_bits']={k:len(v) for k,v in recovery.items()}
   instances={name for name in module.get('cells',{})}
   record['compared_instances']={lane:sorted(name for name in instances if name==prefix+lane) for lane in ('lane0','lane1','jump0','jump1')}
   assert all(record['compared_instances'].values()),'Compared execution/redirect instance missing'
   found.append(record)
 assert len(found)==1,f'Expected one mapped core record, found {len(found)}'
 return {'passed':True,'records':found,'scope':'Core/recovery flip-flop disjointness and compared-instance presence only; not a full protection, parity-path, encoding, RF/arithmetic, placement or timing audit'}

if __name__=='__main__':print(json.dumps(audit(sys.argv[1],len(sys.argv)>2 and sys.argv[2]=='PARITY_REPLAY'),indent=2))
