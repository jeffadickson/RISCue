#!/usr/bin/env python3
"""KV260 ARM userspace control via an exclusively owned, uncached UIO map."""
import argparse,ctypes,json,mmap,struct,time,threading
from pathlib import Path
class RISCue:
    def __init__(self,device='/dev/uio0'):
        self.file=open(device,'r+b',buffering=0);self.mem=mmap.mmap(self.file.fileno(),0x20000)
        self.lock=threading.RLock()
        if self.read(0)!=0x52495343:raise ValueError('Selected UIO device is not RISCue')
        version=self.read(4)
        if version&255!=1 or (version>>8)&255!=2:raise ValueError('Unsupported AXI or injection ABI')
        self.words=self.read(0x34);self.clock_hz=self.read(0x38)
        if self.words>8192 or self.words<16:raise ValueError('Invalid SRAM size')
    def read(self,offset):
        if offset&3 or not 0<=offset<0x20000:raise ValueError('Unaligned/out-of-range offset')
        return ctypes.c_uint32.from_buffer(self.mem,offset).value
    def write(self,offset,value):
        if offset&3 or not 0<=offset<0x20000 or not 0<=value<=0xffffffff:raise ValueError('Invalid register write')
        ctypes.c_uint32.from_buffer(self.mem,offset).value=value
        # Device-memory mapping and readback order each descriptor/MMIO write.
        self.read(0)
    def stop(self,reset_memory_control=False):
        self.write(0x48,self.read(0x48)&1) # disarm first
        self.write(8,4 if reset_memory_control else 0)
    def run(self):
        self.stop()
        self.write(8,1)
    def irq(self,asserted):
        control=self.read(8)
        if not control&1:raise ValueError("Boot the core before requesting an IRQ")
        self.write(8,(control&1)|(2 if asserted else 0))
    def status(self):
        names={'pc':0x10,'mcause':0x14,'mtval':0x18,'flags':0x1c,'corrected':0x20,'uncorrectable':0x24,'disagreement':0x28,'fatal_events':0x2c,'last_instruction':0x3c,'campaign':0x64,'accepted_attempted':0x68}
        out={k:self.read(v) for k,v in names.items()};bits=self.read(0xc)
        # Monotonic high/low snapshot while the core is running.
        while True:
            hi=self.read(0x78);lo=self.read(0x30)
            if hi==self.read(0x78):break
        out.update(run=bool(bits&1),fatal=bool(bits&2),trap_observed=bool(bits&4),busy=bool(bits&8),bridge_fault=bool(bits>>31),retired=(hi<<32)|lo,clock_hz=self.clock_hz,ram_bytes=self.words*4)
        return out
    def image(self,data):
        size=self.words*4;image=bytearray(size)
        if data.startswith(b'\x7fELF'):
            if len(data)<52 or data[4:6]!=b'\x01\x01':raise ValueError('Expected ELF32 little endian')
            h=struct.unpack_from('<16sHHIIIIIHHHHHH',data)
            if h[1]!=2 or h[2]!=243 or h[4]!=0 or h[7]&~1:raise ValueError('Expected RV32 executable, entry zero, ILP32 without F/D/E/TSO flags')
            if h[9]!=32 or h[10]>128:raise ValueError('Unsupported program headers')
            executable_entry=False
            for i in range(h[10]):
                pos=h[5]+i*32
                if pos+32>len(data):raise ValueError('Truncated program headers')
                typ,off,vaddr,paddr,filesz,memsz,flags,align=struct.unpack_from('<8I',data,pos)
                if typ!=1:continue
                if filesz>memsz or off+filesz>len(data) or paddr!=vaddr or paddr+memsz>size:raise ValueError('Invalid load segment')
                image[paddr:paddr+filesz]=data[off:off+filesz]
                executable_entry |= bool(flags&1 and paddr==0 and filesz>0)
            if not executable_entry:raise ValueError('Entry zero is not backed by an executable load segment')
        else:
            if len(data)>size:raise ValueError('Raw binary exceeds SRAM')
            image[:len(data)]=data
        return image
    def load(self,data):
        image=self.image(data) # validate before resetting the running core
        with self.lock:
            self.stop(True)
            for offset in range(0,len(image),4):self.write(0x10000+offset,int.from_bytes(image[offset:offset+4],'little'))
            # Full readback verifies SRAM load and catches a wrong UIO/base map.
            for offset in range(0,len(image),4):
                if self.read(0x10000+offset)!=int.from_bytes(image[offset:offset+4],'little'):raise IOError(f'Load mismatch at {offset:#x}')
        return {'loaded_bytes':len(data),'ram_bytes':len(image),'entry':0}
    def mailbox(self):
        with self.lock:
            self.stop()
            address=self.words*4-256
            return {'address':address,'words':[self.read(0x10000+address+i*4) for i in range(16)]}
    def inject(self,target=8,index=None,mask='1',delay=1,count=1,gap=2,trigger_kind=0,trigger_pc=0,index_step=0,rotate=False,stop_on_fatal=True,timeout=3):
        index=self.words-1 if index is None else index
        mask=int(str(mask),16)
        widths={1:39,2:32,3:32,4:32,8:39,9:35,10:35,11:35,12:321,13:321,14:321,15:307}
        if target in (5,6,7):width=512 if 0<=index<7 else 447 if index==7 else 0
        else:width=widths.get(target,0)
        tmr=bool(self.read(4)&0x10000)
        valid_index=(target==1 and not tmr and 0<=index<32) or (target in (2,3,4) and tmr and 0<=index<32) or (target in (5,6,7) and 0<=index<8) or (target==8 and 0<=index<self.words) or (target in range(9,15) and index==0) or (target==15 and index in (0,1,2,256,257,258))
        if not valid_index or not 0<mask<1<<width:raise ValueError('Invalid target/index/mask for this hardware profile')
        if not 1<=delay<=0xffffffff or not 1<=count<=65535 or not 2<=gap<=0xffffffff or trigger_kind not in (0,1,2):raise ValueError('Invalid campaign schedule')
        if not 0<=trigger_pc<=0xffffffff or not 0<=index_step<=0xffffffff:raise ValueError('Invalid PC/step')
        if not self.read(4)&0x20000:raise ValueError('FI disabled in this bitstream')
        with self.lock:
            if not self.read(8)&1:raise ValueError('Boot the core before injection')
            token=self.read(0x48)&1;self.write(0x48,token)
            deadline=time.monotonic()+timeout
            while self.read(0x64)&0x100:
                if time.monotonic()>deadline:raise TimeoutError('Previous campaign did not disarm')
                time.sleep(.001)
            before=(self.read(0x64)>>9)&1
            for addr,v in [(0x40,target),(0x44,index),(0x4c,delay),(0x50,count),(0x54,gap),(0x58,trigger_pc),(0x5c,trigger_kind|(int(rotate)<<2)|(int(stop_on_fatal)<<3)),(0x60,index_step)]:self.write(addr,v)
            for n in range(16):self.write(0x80+n*4,(mask>>(n*32))&0xffffffff)
            self.write(0x48,token|2);self.write(0x48,(token^1)|2)
            try:
                while ((self.read(0x64)>>9)&1)==before:
                    if time.monotonic()>deadline:raise TimeoutError('Campaign timed out')
                    time.sleep(.001)
                result=self.status()
                if result['campaign']&255:raise RuntimeError('Campaign status '+str(result['campaign']&255))
                return result
            finally:self.write(0x48,token^1)
    def close(self):self.mem.close();self.file.close()
def main():
    p=argparse.ArgumentParser();p.add_argument('--device',default='/dev/uio0');p.add_argument('action',choices=['status','load','run','stop','irq','mailbox','inject']);p.add_argument('value',nargs='?');p.add_argument('--target',type=int,default=8);p.add_argument('--index',type=int);p.add_argument('--mask',default='1');a=p.parse_args()
    d=RISCue(a.device)
    try:
        if a.action=='load':out=d.load(Path(a.value).read_bytes())
        elif a.action=='inject':out=d.inject(a.target,a.index,a.mask)
        elif a.action=='mailbox':out=d.mailbox()
        elif a.action=='irq':d.irq(a.value=='1');out=d.status()
        elif a.action in ('run','stop'):getattr(d,a.action)();out=d.status()
        else:out=d.status()
        print(json.dumps(out,indent=2))
    finally:d.close()
if __name__=='__main__':main()
