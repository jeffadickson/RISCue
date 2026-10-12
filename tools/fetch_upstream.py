#!/usr/bin/env python3
"""Fetch pinned repositories; refuse to overwrite an altered checkout."""
import json,subprocess
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
def git(path,*args):return subprocess.check_output(['git','-C',str(path),*args],text=True).strip()
for name,item in json.loads((ROOT/'upstream.lock.json').read_text()).items():
 p=ROOT/'third_party'/name;p.mkdir(parents=True,exist_ok=True)
 if not (p/'.git').exists():
  subprocess.run(['git','init',str(p)],check=True,stdout=subprocess.DEVNULL)
  git(p,'remote','add','origin',item['url'])
 elif git(p,'remote','get-url','origin')!=item['url']:raise SystemExit(f'{name}: wrong origin')
 if git(p,'status','--porcelain'):raise SystemExit(f'{name}: dirty checkout; refusing overwrite')
 try:head=git(p,'rev-parse','HEAD')
 except subprocess.CalledProcessError:head=None
 if head!=item['commit']:
  git(p,'fetch','--depth=1','origin',item['commit']);git(p,'checkout','--detach',item['commit'])
 assert git(p,'rev-parse','HEAD')==item['commit']
 print(name,item['commit'])
