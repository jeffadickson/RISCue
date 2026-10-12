#!/usr/bin/env python3
"""Validate the loader before MMIO/reset side effects; no hardware required."""
import importlib.util,struct,unittest
from pathlib import Path
module=Path(__file__).resolve().parents[1]/'tools/kv260/riscue_ctl.py'
spec=importlib.util.spec_from_file_location('riscue_ctl',module);driver=importlib.util.module_from_spec(spec);spec.loader.exec_module(driver)
def elf(machine=243,flags=1,addr=0,filesz=4,memsz=8,off=256):
 ident=b'\x7fELF\x01\x01\x01'+b'\0'*9
 header=struct.pack('<16sHHIIIIIHHHHHH',ident,2,machine,1,0,52,0,flags,52,32,1,0,0,0)
 ph=struct.pack('<8I',1,off,addr,addr,filesz,memsz,5,4)
 return (header+ph).ljust(256,b'\0')+b'\x6f\0\0\0'
class LoaderTests(unittest.TestCase):
 def setUp(self):self.device=driver.RISCue.__new__(driver.RISCue);self.device.words=8192
 def test_raw_and_zero_fill(self):
  image=self.device.image(b'\x6f\0\0\0');self.assertEqual(len(image),32768);self.assertEqual(image[:8],b'\x6f'+b'\0'*7)
 def test_valid_elf_and_bss(self):
  image=self.device.image(elf());self.assertEqual(image[:8],b'\x6f'+b'\0'*7)
 def test_reject_wrong_machine_abi_and_range(self):
  for data in (elf(machine=40),elf(flags=2),elf(addr=32768),elf(filesz=9,memsz=8),elf(off=1000),b'0'*32769):
   with self.subTest(data=data[:16]):
    with self.assertRaises(ValueError):self.device.image(data)
 def test_reject_missing_executable_entry(self):
  data=bytearray(elf());struct.pack_into('<I',data,52+24,4)
  with self.assertRaises(ValueError):self.device.image(data)
 def test_reject_elf64(self):
  data=bytearray(elf());data[4]=2
  with self.assertRaises(ValueError):self.device.image(data)
if __name__=='__main__':unittest.main()
