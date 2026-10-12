#!/usr/bin/env python3
"""Validate/pad word-oriented hex for the KC705 image; does not run firmware."""
import argparse,hashlib,json
from pathlib import Path
p=argparse.ArgumentParser(description=__doc__)
p.add_argument('image',type=Path);p.add_argument('output',type=Path);p.add_argument('--words',type=int,default=1024)
a=p.parse_args()
if not 1024<=a.words<=8192:p.error('--words must be between 1024 and 8192')
values=[]
for number,line in enumerate(a.image.read_text().splitlines(),1):
 line=line.split('//')[0].split('#')[0].strip()
 if not line:continue
 if len(line)!=8 or any(c not in '0123456789abcdefABCDEF' for c in line):p.error(f'Line {number}: expected one 8-digit word')
 values.append(int(line,16))
if not values or len(values)>a.words:p.error('Image must be nonempty and fit memory')
count=len(values);values += [0]*(a.words-count)
a.output.parent.mkdir(parents=True,exist_ok=True)
a.output.write_text(''.join(f'{word:08x}\n' for word in values))
a.output.with_suffix('.json').write_text(json.dumps({'source':str(a.image),'source_sha256':hashlib.sha256(a.image.read_bytes()).hexdigest(),'program_words':count,'memory_words':a.words},indent=2)+'\n')
