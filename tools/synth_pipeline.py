#!/usr/bin/env python3
"""Out-of-context Series-7 mapping estimate for the current pipeline core."""
import argparse,hashlib,json,os,shutil,signal,subprocess,time
from pathlib import Path
from pipeline_config import configuration
from audit_pipeline_yosys import audit

ROOT=Path(__file__).resolve().parents[1]
RTL='ft_pkg riscue_pipeline_pkg riscue_rvc riscue_jump_target riscue_execute riscue_muldiv riscue_pipeline_core'.split()

def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--frontend',choices=('slang',),default='slang');p.add_argument('--rf-tmr',type=int,choices=(0,1),default=0);p.add_argument('--timeout',type=int,default=900);a=p.parse_args()
 config=configuration();label=f"{config['pipeline_protection']}-rf{a.rf_tmr}";out=ROOT/'build/yosys-kintex7'/a.frontend/label;out.mkdir(parents=True,exist_ok=True)
 cache=Path(os.environ.get('RISCUE_SYNTH_BUILD_ROOT',str(Path.home()/'.cache/riscue-synthesis')))/a.frontend/label;cache.mkdir(parents=True,exist_ok=True)
 env=os.environ.copy();env['PATH']=str(ROOT/'.tools/oss-cad-suite/bin')+os.pathsep+env['PATH']
 yosys=shutil.which('yosys',path=env['PATH'])
 if not yosys:raise SystemExit('Missing Yosys; run make formal-tools in Ubuntu')
 result={'status':'incomplete','configuration':config,'RF_TMR':a.rf_tmr,'frontend':a.frontend,'top':'riscue_pipeline_core','family':'xc7','reference_board':'KC705 / Kintex-7 XC7K325T','mapping_flow':'Series-7 primitive mapping followed by ABC strash/if uniform 6-input LUT mapping (quick estimate); not ABC9 timing optimization','scope':'Out-of-context mapped cell counts, not device-constrained fitting, placement/routing, timing, protection qualification or Tiny Tapeout area','FI_ENABLE':0,'DEBUG_ENABLE':0,'source_sha256':{f'rtl/{name}.sv':hashlib.sha256((ROOT/'rtl'/(name+'.sv')).read_bytes()).hexdigest() for name in RTL}}
 report=out/'results.json'
 report.write_text(json.dumps(result,indent=2)+'\n')
 started=time.monotonic()
 try:
  result['yosys_version']=subprocess.check_output([yosys,'-V'],env=env,text=True).strip()
  script=cache/'synth.ys'
  abc_script=cache/'abc-map.script';abc_script.write_text('strash\nif -K 6\n')
  convert=['read_slang','--best-effort-hierarchy','--unroll-limit','16384','--top','riscue_pipeline_core','-G',f'RF_TMR={a.rf_tmr}','-G','FI_ENABLE=0','-G','DEBUG_ENABLE=0',*config['iverilog_flags'],*[str(ROOT/'rtl'/(name+'.sv')) for name in RTL]]
  reader=' '.join(convert)
  script.write_text(reader+f'\nhierarchy -check -top riscue_pipeline_core\nproc\nmemory_map\nopt_expr\nopt_clean\nopt_dff\nsetattr -set keep 1 t:$dff t:$adff t:$dffe t:$sdff t:$sdffe\nsetattr -set keep 1 c:*lane0 c:*lane1 c:*jump0 c:*jump1 c:*arithmetic0 c:*arithmetic1\nopt\nsynth_xilinx -family xc7 -top riscue_pipeline_core -flatten -noiopad -noclkbuf -run begin:map_luts\nwrite_rtlil \"{cache/"pre-lut.il"}\"\nabc -lut 6 -script \"{abc_script}\"\ntechmap -map +/xilinx/lut_map.v -map +/xilinx/cells_map.v -D LUT_WIDTH=6\nopt_lut_ins -tech xilinx\nsynth_xilinx -family xc7 -top riscue_pipeline_core -noiopad -noclkbuf -run finalize:edif\ncheck -assert\ntee -o "{cache/"statistics.json"}" stat -json -top riscue_pipeline_core\nwrite_json "{cache/"netlist.json"}"\n')
  result['conversion_command']=convert;result['synthesis_command']=[yosys]+(['-m','slang'] if a.frontend=='slang' else [])+['-Q','-q','-l',str(cache/'yosys-full.log'),'-s',str(script)]
  with (out/'console.log').open('w') as log:
   process=subprocess.Popen(result['synthesis_command'],stdout=log,stderr=subprocess.STDOUT,env=env,start_new_session=True)
   try:
    code=process.wait(timeout=a.timeout)
   except subprocess.TimeoutExpired:
    os.killpg(process.pid,signal.SIGKILL);process.wait();raise
   if code:raise subprocess.CalledProcessError(code,result['synthesis_command'])
  statistics=json.loads((cache/'statistics.json').read_text());design=statistics.get('design') or statistics['modules']['\\riscue_pipeline_core'];cells=design['num_cells_by_type']
  cells={key.rsplit(chr(92),1)[-1]:sum(value for kind,value in design['num_cells_by_type'].items() if kind.rsplit(chr(92),1)[-1]==key.rsplit(chr(92),1)[-1]) for key in design['num_cells_by_type']}
  result['cells_by_type']=cells;result['resources']={'LUT_cells':sum(v for k,v in cells.items() if k.startswith('LUT')),'flip_flop_cells':sum(v for k,v in cells.items() if k.startswith('FD')),'DSP48_cells':sum(v for k,v in cells.items() if k.startswith('DSP48')),'RAMB18_cells':sum(v for k,v in cells.items() if k.startswith('RAMB18')),'RAMB36_cells':sum(v for k,v in cells.items() if k.startswith('RAMB36')),'CARRY4_cells':cells.get('CARRY4',0)}
  result['replica_audit']=audit(cache/'netlist.json',config['pipeline_protection']=='PARITY_REPLAY')
  result['status']='pass';result['statistics']=statistics;shutil.copyfile(cache/'statistics.json',out/'statistics.json');shutil.copyfile(script,out/'synth.ys');shutil.copyfile(abc_script,out/'abc-map.script')
  result['netlist_path']=str(cache/'netlist.json')
 except subprocess.TimeoutExpired as e:result['status']='timeout';result['error']=str(e)
 except Exception as e:result['status']='error';result['error']=str(e)
 if (cache/'yosys-full.log').exists():shutil.copyfile(cache/'yosys-full.log',out/'yosys.log')
 result['seconds']=round(time.monotonic()-started,2);report.write_text(json.dumps(result,indent=2)+'\n');print(json.dumps({key:result[key] for key in ('status','resources','error','replica_audit') if key in result},indent=2));print('Report:',report)
 if result['status']!='pass':raise SystemExit(1)

if __name__=='__main__':main()
