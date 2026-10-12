#!/usr/bin/env python3
"""Download the pinned free suite; verify SHA256 before extracting. Linux/WSL x86-64."""
import hashlib,json,platform,tarfile,urllib.request,os
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
if platform.system()!='Linux' or platform.machine() not in ('x86_64','AMD64'):
 raise SystemExit('Use Linux x86-64 or Windows WSL2; this lock pins that platform.')
item=json.loads((ROOT/'tools/formal-tools.lock.json').read_text())['linux-x64']
dest=ROOT/'.tools';dest.mkdir(exist_ok=True)
archive=dest/'suite.tgz'
if not archive.exists():
 with urllib.request.urlopen(item['url']) as src,archive.with_suffix('.part').open('wb') as out:
  import shutil;shutil.copyfileobj(src,out)
 archive.with_suffix('.part').rename(archive)
if hashlib.file_digest(archive.open('rb'),'sha256').hexdigest()!=item['sha256']:
 raise SystemExit('Suite SHA256 mismatch; remove .tools/suite.tgz and retry.')
if not (dest/'oss-cad-suite/bin/sby').exists():
 with tarfile.open(archive) as t:t.extractall(dest,filter='data')
print('Formal tools installed:',dest/'oss-cad-suite/bin')

import zipfile
item=json.loads((ROOT/'tools/formal-tools.lock.json').read_text())['sv2v']
archive=dest/'sv2v.zip'
if not archive.exists():urllib.request.urlretrieve(item['url'],archive)
if hashlib.file_digest(archive.open('rb'),'sha256').hexdigest()!=item['sha256']:
 raise SystemExit('sv2v SHA256 mismatch')
if not (dest/'sv2v-Linux/sv2v').exists():
 with zipfile.ZipFile(archive) as z:z.extractall(dest)
(dest/'sv2v-Linux/sv2v').chmod(0o755)
