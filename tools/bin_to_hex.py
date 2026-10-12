#!/usr/bin/env python3
"""Convert a little-endian firmware binary to full-word $readmemh image."""
import argparse
from pathlib import Path
p=argparse.ArgumentParser(description=__doc__)
p.add_argument('binary',type=Path);p.add_argument('output',type=Path);p.add_argument('--words',type=int,default=1024)
a=p.parse_args();data=a.binary.read_bytes()
if a.words<=0 or len(data)>4*a.words:p.error('Binary must fit in positive --words capacity.')
data=data.ljust(a.words*4,b'\0')
a.output.write_text(''.join(f'{int.from_bytes(data[i:i+4],"little"):08x}\n' for i in range(0,len(data),4)))
