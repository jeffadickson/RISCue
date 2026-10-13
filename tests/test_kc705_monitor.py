import importlib.util,struct,unittest,zlib
from pathlib import Path
spec=importlib.util.spec_from_file_location('monitor',Path(__file__).parents[1]/'tools/kc705_monitor.py');m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
def elf(entry=0x102,memsz=9,paddr=0x100):
    ident=b'\x7fELF\x01\x01\x01'+bytes(9)
    header=ident+struct.pack('<HHIIIIIHHHHHH',2,243,1,entry,52,0,1,52,32,1,0,0,0)
    return header+struct.pack('<IIIIIIII',1,84,paddr,paddr,5,memsz,5,1)+b'abcde'
class Tests(unittest.TestCase):
    def test_crc_known(self):
        self.assertEqual(zlib.crc32(b'123456789'),0xcbf43926)
        self.assertEqual(len(m.frame(4,3,0x100,42)),20)
    def test_load_bss_padding(self):
        entry,words=m.elf_words(elf(),1024)
        self.assertEqual(entry,0x102);self.assertEqual(words,[(0x100,0x64636261),(0x104,0x65),(0x108,0)])
    def test_reject_invalid(self):
        for raw in [elf(entry=1),elf(entry=0x200),elf(memsz=4),elf(paddr=1024),elf()[:-1],b'bad']:
            with self.assertRaises(ValueError):m.elf_words(raw,1024)
    def test_reply_validation(self):
        body=struct.pack('<BBIII',4,0,0x100,123,456);raw=m.REPLY+body+struct.pack('<I',zlib.crc32(body))
        self.assertEqual(m.decode_reply(raw,4,0x100),(123,456))
        for bad in [raw[:-1],raw[:-1]+bytes([raw[-1]^1])]:
            with self.assertRaises(ValueError):m.decode_reply(bad,4,0x100)
        with self.assertRaises(ValueError):m.decode_reply(raw,5,0x100)
    def test_retry_identical_request(self):
        class Port:
            def __init__(self):self.requests=[];self.buf=bytearray()
            def write(self,raw):
                self.requests.append(raw)
                if len(self.requests)==2:
                    body=struct.pack('<BBIII',raw[2],0,0,123,0);self.buf=bytearray(m.REPLY+body+struct.pack('<I',zlib.crc32(body)))
            def flush(self):pass
            def read(self,n):
                if not self.buf:return b''
                b=self.buf[:n];del self.buf[:n];return b
        port=Port();monitor=m.Monitor(port,timeout=.001)
        self.assertEqual(monitor.command(3,0,42),(123,0));self.assertEqual(port.requests[0],port.requests[1])
if __name__=='__main__':unittest.main()
