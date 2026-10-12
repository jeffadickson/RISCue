import os
import cocotb
from cocotb.triggers import ClockCycles,FallingEdge,Timer
from test_ft import start,boot,inject,encode,TMR
@cocotb.test()
async def injection_qualification_and_reporting(d):
 await start(d);loop=(0x6f).to_bytes(4,'little');await boot(d,loop)
 enabled=os.environ.get('FI_ENABLE','1')=='1'
 invalid=[(15,0),(8,8192),(8,0xffffffff),(1 if TMR else 2,20)]
 for target,index in invalid:
  await FallingEdge(d.clk);d.fi_target.value=target;d.fi_index.value=index;d.fi_mask.value=1;d.fi_valid.value=1
  await Timer(1,unit='ns');assert int(d.fi_ack.value)==0
  await ClockCycles(d.clk,1);await FallingEdge(d.clk);d.fi_valid.value=0
 if not enabled:
  for target,index in [(8,16),(5,0),(12,0),(2 if TMR else 1,20)]:
   await FallingEdge(d.clk);d.fi_target.value=target;d.fi_index.value=index;d.fi_mask.value=3;d.fi_valid.value=1
   await Timer(1,unit='ns');assert int(d.fi_ack.value)==0
   await ClockCycles(d.clk,1);await FallingEdge(d.clk);d.fi_valid.value=0
  await ClockCycles(d.clk,100);await FallingEdge(d.clk)
  assert not int(d.fatal.value) and int(d.soc.ram.mem[16].value)==0 and int(d.sticky_flags.value)==0
  return
 # Saturation check: initialize the three recorder replicas to the same logical value.
 await FallingEdge(d.clk)
 saturated_corrected=0xffffffff<<257
 for replica in ['report0','report1','report2']:getattr(d.soc.reporter,replica).value=saturated_corrected
 await inject(d,8,16,1);await ClockCycles(d.clk,100);await FallingEdge(d.clk)
 assert int(d.corrected_count.value)==0xffffffff and int(d.sticky_flags.value)&0x100
 assert int(d.first_address.value)==64
 # Deterministic same-edge write+upset: force a test SRAM write through core's request wires
 # is covered by legacy RMW tests; this interface case rejects mode/index abuse instead.

 if not TMR:
  await boot(d,loop);await inject(d,1,20,3);await ClockCycles(d.clk,40);await FallingEdge(d.clk)
  assert int(d.fatal.value) and int(d.uncorrectable_count.value)>0 and int(d.fatal_count.value)>0
  assert int(d.first_flags.value)&2 and int(d.first_address.value)==20
