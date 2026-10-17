#!/usr/bin/env python3
"""Canonical pipeline selection, flags and provenance; RF mode is independent."""
import argparse,hashlib,json,os
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
def configuration(mode=None,experimental=None):
 mode=mode if mode is not None else os.environ.get('PIPELINE_PROTECTION','TMR')
 experimental=str(experimental if experimental is not None else os.environ.get('ALLOW_EXPERIMENTAL_PARITY','0'))
 if mode not in ('TMR','PARITY_REPLAY','PLAIN'): raise ValueError('Invalid PIPELINE_PROTECTION: '+mode)
 if experimental not in ('0','1'): raise ValueError('Experimental opt-in must be 0 or 1')
 if mode=='PARITY_REPLAY' and experimental!='1': raise ValueError('PARITY_REPLAY requires ALLOW_EXPERIMENTAL_PARITY=1')
 ident={'TMR':0,'PARITY_REPLAY':1,'PLAIN':2}[mode]
 return {'pipeline_protection':mode,'mode_id':ident,'experimental':mode=='PARITY_REPLAY','explicit_opt_in':experimental=='1','fi_abi':None if ident==2 else (3 if ident==1 else 2),'iverilog_flags':(['-DRISCUE_PLAIN_MEMORY'] if ident==2 else [])+[f'-DRISCUE_PIPELINE_PROTECTION={ident}',f'-DRISCUE_ALLOW_EXPERIMENTAL_PARITY={experimental}'],'core_sha256':hashlib.sha256((ROOT/'rtl/riscue_pipeline_core.sv').read_bytes()).hexdigest()}
if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('--mode');p.add_argument('--experimental');p.add_argument('--output',type=Path);a=p.parse_args()
 try: record=configuration(a.mode,a.experimental)
 except ValueError as e:p.error(str(e))
 text=json.dumps(record,indent=2)+'\n'
 if a.output:a.output.parent.mkdir(parents=True,exist_ok=True);a.output.write_text(text,encoding='utf-8')
 print(text,end='')
