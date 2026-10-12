import copy,json,struct,sys,tempfile,unittest
from pathlib import Path
from unittest.mock import patch
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'tools'))
from software_profile import load_profile,generate_make
from check_elf import audit_header,audit_attributes,audit_disassembly,check,GROUPS
from bitmanip_vectors import NAMES,instruction
P=load_profile();ARCH='rv32i2p1_m2p0_c2p0_zicsr2p0_zifencei2p0_zicntr2p0_zbb1p0_zbc1p0_zbs1p0'
def header(flags=1,machine=243,kind=2):
    return b'\x7fELF\x01\x01\x01'+bytes(9)+struct.pack('<HHIIIIIHHHHHH',kind,machine,1,0,0,0,flags,52,0,0,0,0,0)
def attributes(arch=ARCH):return f'Tag_RISCV_stack_align: 16-bytes\nTag_RISCV_arch: "{arch}"\n'
class ProfileTests(unittest.TestCase):
    def test_flags_generated(self):self.assertIn('-march='+P['isa'],generate_make(P))
    def test_profile_conflict_rejected(self):
        with tempfile.TemporaryDirectory() as t:
            p=copy.deepcopy(P);p['compiler_flags'].append('-march=rv32g');f=Path(t)/'p.json';f.write_text(json.dumps(p))
            with self.assertRaises(ValueError):load_profile(f)
    def test_flag_shell_injection_rejected(self):
        with tempfile.TemporaryDirectory() as t:
            p=copy.deepcopy(P);p['compiler_flags'].append('-Dfoo=$(bad)');f=Path(t)/'p.json';f.write_text(json.dumps(p))
            with self.assertRaises(ValueError):load_profile(f)
    def test_header_valid(self):self.assertEqual(audit_header(header(),P),0)
    def test_bad_headers(self):
        for data in [b'',header()[:40],header(2),header(8),header(16),header(32),header(machine=62),header(kind=1),header()[:4]+b'\x02'+header()[5:]]:
            with self.subTest(data=data):
                with self.assertRaises(ValueError):audit_header(data,P)
    def test_attributes_valid_and_implied(self):audit_attributes(attributes(ARCH+'_zmmul1p0_zca1p0'),P)
    def test_attributes_unsupported(self):
        for ext in ('a2p1','f2p2','d2p2','v1p0','zba1p0','zicond1p0','zbb2p0','xcustom1p0'):
            with self.subTest(ext=ext):
                with self.assertRaises(ValueError):audit_attributes(attributes(ARCH+'_'+ext),P)
    def test_missing_malformed_metadata(self):
        for text in ['',attributes('rv64i2p1'),attributes('rv32i'),attributes(ARCH).replace('16-bytes','4-bytes')]:
            with self.subTest(text=text):
                with self.assertRaises(ValueError):audit_attributes(text,P)
    def test_all_bitmanip(self):
        text='\n'.join(f'{4*n:x}: {instruction(name):08x} {name} x3,x1,x2' for n,name in enumerate(NAMES))
        self.assertEqual(audit_disassembly(text,P),29)
    def test_all_supported_mnemonics(self):
        for ext,names in GROUPS.items():
            for name in names:
                raw='0001' if ext=='c' else '00000013'
                with self.subTest(name=name):self.assertEqual(audit_disassembly(f'0: {raw} {name} x0,x0,0',P),1)
    def test_unavailable_instructions_even_with_safe_attributes(self):
        for name in ('amoadd.w','lr.w','sc.w','fadd.s','vadd.vv','sh1add','czero.eqz','sret','dret','addw','custom'):
            with self.subTest(name=name):
                with self.assertRaises(ValueError):audit_disassembly(f'0: 00000033 {name} x1,x2,x3',P)
    def test_undecoded_and_empty(self):
        for text in ('','0: 00000000 .word 0','0: 0000 .2byte 0','0: 000000000000 .8byte 0','0: 00000013 c.nop'):
            with self.subTest(text=text):
                with self.assertRaises(ValueError):audit_disassembly(text,P)
    def test_pack_zext_h_alias(self):
        self.assertEqual(audit_disassembly('0: 0800c1b3 pack x3,x1,x0',P),1)
        with self.assertRaises(ValueError):audit_disassembly('0: 0820c1b3 pack x3,x1,x2',P)
    def test_reserved_rv32_shamt(self):
        with self.assertRaises(ValueError):audit_disassembly('0: 6200d193 rori x3,x1,32',P)
    def test_removed_extension(self):
        p=copy.deepcopy(P);p['isa']='rv32imc_zicsr'
        with self.assertRaises(ValueError):audit_disassembly('0: 6000d193 rori x3,x1,0',p)
    def test_full_report_and_tool_failure(self):
        with tempfile.TemporaryDirectory() as t:
            f=Path(t)/'a.elf';f.write_bytes(header())
            with patch('check_elf.tool_output',side_effect=[attributes(),'0: 00000013 addi x0,x0,0']):self.assertEqual(check(f,P,'readelf','objdump')['instructions_checked'],1)
            with patch('check_elf.tool_output',side_effect=ValueError('tool failure')):
                with self.assertRaises(ValueError):check(f,P,'readelf','objdump')
if __name__=='__main__':unittest.main()
