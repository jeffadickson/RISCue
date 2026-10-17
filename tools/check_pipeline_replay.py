#!/usr/bin/env python3
import argparse,subprocess
from pathlib import Path
p=argparse.ArgumentParser();p.add_argument('--scenario',type=int,default=1);p.add_argument('--rf',type=int,default=0);p.add_argument('--illegal',type=int,default=1);a=p.parse_args()
r=Path(__file__).resolve().parents[1];out=r/'build'/f'replay-{a.scenario}-{a.rf}';out.parent.mkdir(exist_ok=True)
rtl=['ft_pkg','riscue_pipeline_pkg','riscue_rvc','riscue_jump_target','riscue_execute','riscue_muldiv','riscue_pipeline_core','ft_ecc_ram','ft_event_monitor','riscue_pipeline_soc']
cmd=['iverilog','-g2012','-s','tb_pipeline_replay','-DRISCUE_PIPELINE_PROTECTION=1','-DRISCUE_ALLOW_EXPERIMENTAL_PARITY=1',f'-Ptb_pipeline_replay.SCENARIO={a.scenario}',f'-Ptb_pipeline_replay.RF_TMR={a.rf}','-o',str(out)]+[str(r/'rtl'/(n+'.sv')) for n in rtl]+[str(r/'tests/tb_pipeline_replay.sv')]
c=subprocess.run(cmd,capture_output=True,text=True);assert c.returncode==0,c.stderr
run=subprocess.run(['vvp',str(out),f'+illegal={a.illegal}'],capture_output=True,text=True,timeout=30);print(run.stdout);assert run.returncode==0,run.stderr
expected=f'PASS parity fail-stop scenario={a.scenario}' if a.scenario in (2,3,4,6,9) else 'PASS pipeline replay'
assert expected in run.stdout,('Missing expected outcome',expected,run.stdout)
