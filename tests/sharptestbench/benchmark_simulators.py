#!/usr/bin/env python3
"""Repeat prebuilt, self-checking RISCue CPU simulators with monotonic timing."""
import argparse, json, re, statistics, subprocess, time
from pathlib import Path

p=argparse.ArgumentParser()
p.add_argument("--runs",type=int,default=150)
p.add_argument("--output",default="build/stb/benchmark.json")
p.add_argument("--native",required=True)
p.add_argument("--icarus",required=True)
a=p.parse_args()
if a.runs<5: p.error("at least 5 repetitions are required")
results={}
for name,cmd in (("verilator",[a.native]),("icarus",["vvp",a.icarus])):
    durations=[]
    for i in range(a.runs+3):
        t=time.perf_counter_ns()
        proc=subprocess.run(cmd,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True)
        dt=time.perf_counter_ns()-t
        if proc.returncode: raise RuntimeError(f"{name} failed at run {i}: {proc.stdout[-5000:]}")
        match=re.search(r"PASS pipeline smoke RF_TMR=\s*0:\s*(\d+) retirements in\s*(\d+) clocks",proc.stdout)
        if not match or tuple(map(int,match.groups()))!=(20,165):
            raise RuntimeError(f"{name} invalid architectural result at run {i}: {proc.stdout[-2000:]}")
        if i>=3: durations.append(dt/1e6)
    results[name]={"runs":a.runs,"median_process_ms":statistics.median(durations),"minimum_process_ms":min(durations),"mean_process_ms":statistics.mean(durations),"retirements":20,"sim_cycles":165}
results["ratio_icarus_over_verilator"]=results["icarus"]["median_process_ms"]/results["verilator"]["median_process_ms"]
results["method"]="Independent process launch for each run; includes loader/startup; excludes compilation. Same HDL retirement oracle, not a native-access-versus-GPI comparison."
Path(a.output).parent.mkdir(parents=True,exist_ok=True)
Path(a.output).write_text(json.dumps(results,indent=2)+"\n")
print(json.dumps(results,indent=2))
