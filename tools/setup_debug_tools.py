#!/usr/bin/env python3
"""Download checksum-pinned Ubuntu x86-64 OpenOCD/GDB into .tools, without root.

On other platforms install these tools natively and set OPENOCD/GDB. This bundle
is tested on Ubuntu 24.04 x86-64 and uses host libc and standard C++ libraries.
"""
import concurrent.futures,hashlib,json,platform,shutil,subprocess,urllib.request
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
def main():
 if platform.system()!='Linux' or platform.machine() not in ('x86_64','AMD64'):
  raise SystemExit('Install OpenOCD and a RISC-V-capable GDB natively; set OPENOCD and GDB.')
 if not shutil.which('dpkg-deb'):raise SystemExit('dpkg-deb required for local bundle extraction')
 items=json.loads((ROOT/'debug/toolchain-lock.json').read_text());base=ROOT/'.tools/debug';base.mkdir(parents=True,exist_ok=True)
 def get(item):
  path=base/item['name']
  if not path.exists() or hashlib.sha256(path.read_bytes()).hexdigest()!=item['sha256']:
   with urllib.request.urlopen(item['url'],timeout=60) as f:path.write_bytes(f.read())
  if hashlib.sha256(path.read_bytes()).hexdigest()!=item['sha256']:raise RuntimeError('Checksum mismatch: '+item['name'])
  return path
 with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:paths=list(pool.map(get,items))
 for path in paths:subprocess.run(['dpkg-deb','-x',str(path),str(base/'root')],check=True)
 for name in ('openocd','gdb-multiarch'):
  p=base/name
  p.write_text('#!/bin/sh\nbase=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)\nexport LD_LIBRARY_PATH="$base/root/usr/lib/x86_64-linux-gnu${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"\nexport OPENOCD_SCRIPTS="$base/root/usr/share/openocd/scripts"\nexec "$base/root/usr/bin/'+name+'" "$@"\n');p.chmod(0o755)
  subprocess.run([str(p),'--version'],check=True)
if __name__=='__main__':main()
