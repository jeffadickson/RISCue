#!/usr/bin/env python3
"""RISCue KC705 binary UART monitor client; ELF32 little-endian RV32 loader."""
import argparse
import json
import struct
import time
import zlib
from pathlib import Path

MAGIC=b'\xa5\x5a'; REPLY=b'\x5a\xa5'
ERRORS={1:'unknown command',2:'packet CRC',3:'invalid address/argument',4:'busy or unsafe ownership',5:'memory/bus fault',6:'timeout; inspect status',7:'injection disabled/rejected',8:'sequence collision'}
class MonitorError(RuntimeError):pass

def frame(seq,command,address=0,data=0,aux=0):
    body=struct.pack('<BBIII',seq,command,address,data,aux)
    return MAGIC+body+struct.pack('<I',zlib.crc32(body))

def decode_reply(raw,seq,address):
    if len(raw)!=20 or raw[:2]!=REPLY or zlib.crc32(raw[2:16])!=struct.unpack_from('<I',raw,16)[0]:
        raise ValueError('invalid reply framing/CRC')
    got,status,echo,data,aux=struct.unpack('<BBIII',raw[2:16])
    if got!=seq or echo!=address:raise ValueError('stale reply')
    if status:raise MonitorError(f'{status}: {ERRORS.get(status,"unknown status")}')
    return data,aux

class Monitor:
    def __init__(self,port,timeout=2,retries=3):
        self.port=port;self.timeout=timeout;self.retries=retries;self.seq=0
    def command(self,command,address=0,data=0,aux=0):
        seq=self.seq;self.seq=(self.seq+1)&255
        request=frame(seq,command,address,data,aux)
        for _ in range(self.retries):
            self.port.write(request);self.port.flush();deadline=time.monotonic()+self.timeout;buf=bytearray()
            while time.monotonic()<deadline:
                buf.extend(self.port.read(1))
                while len(buf)>=2 and buf[:2]!=REPLY:del buf[0]
                if len(buf)==20:
                    try:return decode_reply(bytes(buf),seq,address)
                    except ValueError:buf.clear()
        raise TimeoutError('No valid monitor response; retries used the same sequence and payload')
    def connect(self):
        # An independently started client may reuse the board's last sequence.
        try:identity,size=self.command(0)
        except MonitorError as exc:
            if not str(exc).startswith('8:'):raise
            identity,size=self.command(0)
        if identity!=0x52495343:raise MonitorError('unexpected monitor identity')
        return size
    def load(self,path,size):
        entry,words=elf_words(Path(path).read_bytes(),size)
        self.command(5)
        for address,value in words:self.command(3,address,value)
        for address,value in words:
            actual,_=self.command(2,address)
            if actual!=value:raise MonitorError(f'readback mismatch at {address:#x}')
        return entry,len(words)*4

def elf_words(raw,memory_bytes):
    """Validate all segments before changing hardware, then form full ECC words."""
    if len(raw)<52 or raw[:7]!=b'\x7fELF\x01\x01\x01':raise ValueError('ELF32 little-endian version 1 required')
    typ,machine,version,entry,phoff,_,flags,ehsize,phsize,phnum,*_=struct.unpack_from('<HHIIIIIHHHHHH',raw,16)
    if typ!=2 or machine!=243 or version!=1 or ehsize!=52 or phsize!=32 or not phnum:raise ValueError('RV32 executable with program headers required')
    if flags&~1:raise ValueError('Only soft-float RV32 ABI, optionally compressed, is supported')
    if entry&1 or not 0<=entry<memory_bytes:raise ValueError('entry outside RAM or odd')
    if phoff+phsize*phnum>len(raw):raise ValueError('truncated program headers')
    image={};executable=False
    for i in range(phnum):
        kind,offset,vaddr,paddr,filesz,memsz,permissions,align=struct.unpack_from('<IIIIIIII',raw,phoff+i*phsize)
        if kind in (2,3):raise ValueError('dynamic/interpreted executables unsupported')
        if kind!=1:continue
        if vaddr!=paddr or filesz>memsz or offset+filesz>len(raw) or paddr+memsz>memory_bytes:raise ValueError('invalid or out-of-range load segment')
        if align>1 and (align&(align-1) or (vaddr-offset)%align):raise ValueError('invalid segment alignment')
        executable|=bool(permissions&1 and paddr<=entry<paddr+memsz)
        segment=raw[offset:offset+filesz]+bytes(memsz-filesz)
        for j,b in enumerate(segment):
            a=paddr+j
            if a in image and image[a]!=b:raise ValueError('conflicting load segments')
            image[a]=b
    if not executable:raise ValueError('entry is not in an executable load segment')
    addresses=sorted({a&~3 for a in image})
    if addresses and addresses[-1]+4>memory_bytes:raise ValueError('padded word exceeds RAM')
    return entry,[(a,sum(image.get(a+j,0)<<(8*j) for j in range(4))) for a in addresses]

def main():
    number=lambda s:int(s,0)
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--port',required=True);p.add_argument('--baud',type=int,default=115200)
    sub=p.add_subparsers(dest='command',required=True)
    sub.add_parser('ping');sub.add_parser('stop');sub.add_parser('recover');sub.add_parser('status')
    q=sub.add_parser('run');q.add_argument('address',type=number,nargs='?',default=0)
    q=sub.add_parser('read');q.add_argument('address',type=number);q.add_argument('--words',type=int,default=1)
    q=sub.add_parser('write');q.add_argument('address',type=number);q.add_argument('value',type=number)
    q=sub.add_parser('inject');q.add_argument('address',type=number);q.add_argument('mask',type=number)
    q=sub.add_parser('load');q.add_argument('elf');q.add_argument('--run',action='store_true')
    args=p.parse_args()
    import serial
    with serial.Serial(args.port,args.baud,timeout=.05,write_timeout=2) as port:
        monitor=Monitor(port);size=monitor.connect()
        if args.command=='ping':print(json.dumps({'memory_bytes':size,'protocol':1}))
        elif args.command=='status':
            names=['pc_flags','corrected_uncorrectable','disagreement_fatal','last_address_syndrome','cause_tval','retirements']
            print(json.dumps({name:monitor.command(1,i) for i,name in enumerate(names)},indent=2))
        elif args.command=='load':
            entry,count=monitor.load(args.elf,size);print(f'Loaded and verified {count} bytes; entry {entry:#x}')
            if args.run:monitor.command(4,entry)
        elif args.command=='read':
            if args.words<1:raise ValueError('positive word count required')
            for i in range(args.words):
                address=args.address+4*i;print(f'{address:08x}: {monitor.command(2,address)[0]:08x}')
        elif args.command=='write':monitor.command(3,args.address,args.value)
        elif args.command=='inject':
            if not 0<args.mask<1<<39:raise ValueError('mask must select 1–39 codeword bits')
            monitor.command(6,args.address,args.mask&0xffffffff,args.mask>>32)
        else:print(monitor.command({'run':4,'stop':5,'recover':7}[args.command],getattr(args,'address',0)))
if __name__=='__main__':main()
