#!/usr/bin/env python3
"""Decode diagnostic RISCue snapshots from serial or saved terminal lines."""
import argparse,json,sys
p=argparse.ArgumentParser(description=__doc__);p.add_argument('--port');p.add_argument('--baud',type=int,default=115200);a=p.parse_args()
if a.port:
 try:import serial
 except ImportError:raise SystemExit('Install optional dependency: python3 -m pip install pyserial')
 stream=serial.Serial(a.port,a.baud,timeout=2,rtscts=False,dsrdtr=False)
else:stream=sys.stdin.buffer
keys=['pc','cause','tval','flags','corrected','uncorrectable','disagreement','fatal_count','retired','status']
try:
 while True:
  raw=stream.readline()
  if not raw:
   if a.port:continue
   break
  parts=raw.decode('ascii',errors='replace').split()
  if len(parts)!=11 or parts[0]!='RISCue':continue
  try:record=dict(zip(keys,[int(v,16) for v in parts[1:]]))
  except ValueError:continue
  status=record['status'];record.update(halted=bool(status&1),fatal=bool(status&2),trap=bool(status&4))
  print(json.dumps(record),flush=True)
except KeyboardInterrupt:pass
finally:
 if a.port:stream.close()
