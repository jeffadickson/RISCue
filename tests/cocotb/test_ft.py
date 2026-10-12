import os,json,itertools,hashlib
from pathlib import Path
import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles,FallingEdge,Timer
ROOT=Path(os.environ['PROJECT_ROOT']);TMR=os.environ.get('RF_TMR','0')=='1'
PARITY={1,2,4,8,16,32}
def encode(data):
 code=0;j=0
 for pos in range(1,39):
  if pos not in PARITY:code|=((data>>j)&1)<<(pos-1);j+=1
 for p in PARITY:
  bit=sum((code>>(i-1))&1 for i in range(1,39) if i&p)%2;code|=bit<<(p-1)
 return code|((code.bit_count()%2)<<38)
def decode(code):
 syndrome=0
 for p in PARITY:
  if sum((code>>(i-1))&1 for i in range(1,39) if i&p)%2:syndrome|=p
 if code.bit_count()%2:
  if syndrome==0:code^=1<<38
  elif syndrome<=38:code^=1<<(syndrome-1)
  else:raise AssertionError('Uncorrectable ECC')
 elif syndrome:raise AssertionError('Uncorrectable ECC')
 return sum(((code>>(pos-1))&1)<<j for j,pos in enumerate(i for i in range(1,39) if i not in PARITY))
def reg(d,index):
 if not index:return 0
 c=d.soc.core
 return ((int(c.tmr0[index].value)&int(c.tmr1[index].value))|(int(c.tmr0[index].value)&int(c.tmr2[index].value))|(int(c.tmr1[index].value)&int(c.tmr2[index].value))) if TMR else decode(int(c.rf[index].value))
async def start(d):
 d.fi_valid.value=0;d.rst_n.value=0
 cocotb.start_soon(Clock(d.clk,10,unit='ns').start())
 await ClockCycles(d.clk,2);await FallingEdge(d.clk)
async def boot(d,data=b'',clear=True):
 d.rst_n.value=0;d.fi_valid.value=0
 await ClockCycles(d.clk,2);await FallingEdge(d.clk)
 if clear:
  for i in range(8192):d.soc.ram.mem[i].value=0
 for i in range(0,len(data),4):d.soc.ram.mem[i//4].value=encode(int.from_bytes(data[i:i+4].ljust(4,b'\0'),'little'))
 await Timer(1,unit='ns');d.rst_n.value=1
async def inject(d,target,index,mask):
 await FallingEdge(d.clk);d.fi_target.value=target;d.fi_index.value=index;d.fi_mask.value=mask;d.fi_valid.value=1
 await Timer(1,unit='ns');assert int(d.fi_ack.value)==1, f'Injection rejected {target}/{index}'
 await ClockCycles(d.clk,1);await FallingEdge(d.clk);d.fi_valid.value=0
async def run_until_halt(d,budget):
 cycles=0
 while cycles<budget:
  await ClockCycles(d.clk,32);await FallingEdge(d.clk);cycles+=32
  if int(d.halted.value):return cycles
 raise AssertionError(f'Timeout PC={int(d.pc.value):08x} insn={int(d.soc.core.retire_insn.value):08x}')
@cocotb.test()
async def upstream_programs(d):
 await start(d);records=[]
 manifest=json.loads((ROOT/'build/upstream/manifest.json').read_text())
 for p in manifest['programs']:
  data=(ROOT/p['binary']).read_bytes();assert hashlib.sha256(data).hexdigest()==p['sha256']
  await boot(d,data)
  cycles=await run_until_halt(d,p['max_cycles'])
  result=reg(d,10)
  assert not int(d.fatal.value) and int(d.trap.value) and int(d.trap_cause.value)==3 and result==p['pass_value'], f"{p['name']} failed a0={result} testnum={reg(d,3)} pc={int(d.pc.value):08x} cause={int(d.trap_cause.value):08x}"
  records.append({'name':p['name'],'pass':True,'cycles_upper_bound':cycles})
  d._log.info('PASS %s (%d-cycle polling bound)',p['name'],cycles)
 (ROOT/'build'/f'upstream_results_{"tmr" if TMR else "ecc"}.json').write_text(json.dumps(records,indent=2))
@cocotb.test()
async def stored_fault_campaign(d):
 await start(d)
 loop=(0x0000006f).to_bytes(4,'little');cases=[]
 # Every ECC storage bit in three words; observe correction and repair, never silent.
 for word in [32,33,34]:
  for bit in range(39):
   await boot(d,loop,clear=(word==32 and bit==0));await inject(d,8,word,1<<bit)
   await ClockCycles(d.clk,180);await FallingEdge(d.clk)
   assert not int(d.fatal.value) and int(d.soc.ram.mem[word].value)==0
   assert int(d.corrected_count.value)>0 and int(d.sticky_flags.value)&0x100
   cases.append({'target':'sram','index':word,'mask':hex(1<<bit),'outcome':'corrected'})
 # All 39 bits of every nonzero ECC RF register, or all 32 bits in each of three TMR replicas.
 for index in range(1,32):
  targets=[2,3,4] if TMR else [1]
  for target in targets:
   for bit in range(32 if TMR else 39):
    await boot(d,loop,clear=False);await inject(d,target,index,1<<bit)
    await ClockCycles(d.clk,36);await FallingEdge(d.clk)
    assert not int(d.fatal.value) and reg(d,index)==0
    assert int(d.corrected_count.value)>0
    if TMR:assert all(int(getattr(d.soc.core,'tmr'+str(r))[index].value)==0 for r in range(3))
    else:assert int(d.soc.core.rf[index].value)==0
    cases.append({'target':target,'index':index,'mask':hex(1<<bit),'outcome':'corrected'})
 # All double-bit combinations in one SRAM codeword; no claim for triple errors.
 for a,b in itertools.combinations(range(39),2):
  await boot(d,loop,clear=False);d.soc.ram.mem[16].value=0
  await inject(d,8,16,(1<<a)|(1<<b));await ClockCycles(d.clk,100);await FallingEdge(d.clk)
  assert int(d.fatal.value) and int(d.uncorrectable_count.value)>0
  cases.append({'target':'sram','index':16,'mask':hex((1<<a)|(1<<b)),'outcome':'detected_fatal'})
  d.rst_n.value=0;d.soc.ram.mem[16].value=0
 (ROOT/'build'/f'fault_results_{"tmr" if TMR else "ecc"}.json').write_text(json.dumps(cases,indent=2))
@cocotb.test()
async def protected_state_and_reporting(d):
 await start(d);loop=(0x0000006f).to_bytes(4,'little');records=[]
 # Every state/control bit of CPU and RAM, each replica; exact XOR on post-edge next state.
 for target,width in [(5,384),(6,384),(7,384),(9,35),(10,35),(11,35),(12,321),(13,321),(14,321)]:
  for bit in range(width):
   await boot(d,loop,clear=False);await inject(d,target,0,1<<bit)
   await ClockCycles(d.clk,4);await FallingEdge(d.clk)
   assert not int(d.fatal.value),f'control {target} bit{bit}'
   if target<8:assert int(d.disagreement_count.value)>0
   elif target<12:assert int(d.disagreement_count.value)>0
   else:assert int(d.sticky_flags.value)&0x8000
   owner,names=(d.soc.core,['c0','c1','c2']) if target<8 else ((d.soc.ram,['s0','s1','s2']) if target<12 else (d.soc.reporter,['report0','report1','report2']))
   assert len({int(getattr(owner,n).value) for n in names})==1
   records.append({'mode':'tmr' if TMR else 'ecc','target':target,'index':0,'mask':hex(1<<bit),'outcome':'repaired'})
 (ROOT/'build'/f'control_results_{"tmr" if TMR else "ecc"}.json').write_text(json.dumps(records,indent=2))
 # Reporter persistence after correctable event and fail-stop event.
 await boot(d,loop);await inject(d,8,16,3);await ClockCycles(d.clk,100);await FallingEdge(d.clk)
 first=(int(d.first_pc.value),int(d.first_address.value),int(d.first_flags.value))
 assert int(d.fatal_count.value)>0 and int(d.sticky_flags.value)&0x800
 await ClockCycles(d.clk,30);await FallingEdge(d.clk)
 assert first==(int(d.first_pc.value),int(d.first_address.value),int(d.first_flags.value))
