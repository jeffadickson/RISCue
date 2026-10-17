#!/usr/bin/env python3
"""Check wrapper selection rejection without external Python packages."""
import os,subprocess,tempfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
rtl=['ft_pkg','riscue_pipeline_pkg','riscue_rvc','riscue_jump_target','riscue_execute','riscue_muldiv','riscue_pipeline_core']
with tempfile.TemporaryDirectory(dir=ROOT/'build') as tmp:
 p=Path(tmp);tb=p/'selection.sv'
 tb.write_text("module tb_selection; parameter integer MODE=0,EXPERIMENTAL=0; riscue_pipeline_core #(.PIPELINE_PROTECTION(MODE),.ALLOW_EXPERIMENTAL_PARITY(EXPERIMENTAL)) dut(.clk(1'b0),.rst_n(1'b0)); initial begin #1;$finish;end endmodule\n")
 for mode,exp,message in [(0,0,None),(2,0,'Invalid PIPELINE_PROTECTION'),(-1,0,'Invalid PIPELINE_PROTECTION'),(1,0,'PARITY_REPLAY'),(1,1,None)]:
  cmd=[os.environ.get('IVERILOG','iverilog'),'-g2012','-s','tb_selection',f'-Ptb_selection.MODE={mode}',f'-Ptb_selection.EXPERIMENTAL={exp}','-o',str(p/'sim')]+[str(ROOT/'rtl'/(n+'.sv')) for n in rtl]+[str(tb)]
  c=subprocess.run(cmd,capture_output=True,text=True);assert c.returncode==0,c.stderr
  run=subprocess.run([os.environ.get('VVP','vvp'),str(p/'sim')],capture_output=True,text=True,timeout=10)
  assert (run.returncode==0 if message is None else run.returncode!=0 and message in run.stdout),run.stdout+run.stderr
  print('PASS wrapper selection',mode,exp)
