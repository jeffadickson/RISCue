#!/usr/bin/env python3
"""Check wrapper selection rejection without external Python packages."""
import os,subprocess,tempfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
rtl=['ft_pkg','riscue_pipeline_pkg','riscue_rvc','riscue_jump_target','riscue_execute','riscue_muldiv','riscue_pipeline_core']
with tempfile.TemporaryDirectory(dir=ROOT/'build') as tmp:
 p=Path(tmp);tb=p/'selection.sv'
 tb.write_text("module tb_selection; parameter integer MODE=0,EXPERIMENTAL=0,RF=0,FI=0,MULTI=0; riscue_pipeline_core #(.PIPELINE_PROTECTION(MODE),.ALLOW_EXPERIMENTAL_PARITY(EXPERIMENTAL),.RF_TMR(RF),.FI_ENABLE(FI),.MULTICYCLE(MULTI)) dut(.clk(1'b0),.rst_n(1'b0)); initial begin #1;$finish;end endmodule\n")
 for mode,exp,message in [(0,0,None),(2,0,None),(3,0,'Invalid PIPELINE_PROTECTION'),(-1,0,'Invalid PIPELINE_PROTECTION'),(1,0,'PARITY_REPLAY'),(1,1,None)]:
  cmd=[os.environ.get('IVERILOG','iverilog'),'-g2012','-s','tb_selection',f'-Ptb_selection.MODE={mode}',f'-Ptb_selection.EXPERIMENTAL={exp}','-o',str(p/'sim')]+[str(ROOT/'rtl'/(n+'.sv')) for n in rtl]+[str(tb)]
  c=subprocess.run(cmd,capture_output=True,text=True);assert c.returncode==0,c.stderr
  run=subprocess.run([os.environ.get('VVP','vvp'),str(p/'sim')],capture_output=True,text=True,timeout=10)
  assert (run.returncode==0 if message is None else run.returncode!=0 and message in run.stdout),run.stdout+run.stderr
  print('PASS wrapper selection',mode,exp)

 for rf,fi in [(1,0),(0,1)]:
  c=subprocess.run([os.environ.get('IVERILOG','iverilog'),'-g2012','-s','tb_selection','-Ptb_selection.MODE=2',f'-Ptb_selection.RF={rf}',f'-Ptb_selection.FI={fi}','-o',str(p/'sim')]+[str(ROOT/'rtl'/(n+'.sv')) for n in rtl]+[str(tb)],capture_output=True,text=True)
  assert c.returncode==0,c.stderr
  run=subprocess.run([os.environ.get('VVP','vvp'),str(p/'sim')],capture_output=True,text=True,timeout=10)
  assert run.returncode!=0 and 'PLAIN requires' in run.stdout,run.stdout+run.stderr
  print('PASS PLAIN rejects protected RF/FI',rf,fi)

 c=subprocess.run([os.environ.get('IVERILOG','iverilog'),'-g2012','-s','tb_selection','-Ptb_selection.MODE=1','-Ptb_selection.EXPERIMENTAL=1','-Ptb_selection.MULTI=1','-o',str(p/'sim')]+[str(ROOT/'rtl'/(n+'.sv')) for n in rtl]+[str(tb)],capture_output=True,text=True)
 assert c.returncode==0,c.stderr
 run=subprocess.run([os.environ.get('VVP','vvp'),str(p/'sim')],capture_output=True,text=True,timeout=10)
 assert run.returncode!=0 and 'MULTICYCLE supports' in run.stdout,run.stdout+run.stderr
 print('PASS rejects multicycle pipeline-parity combination')
