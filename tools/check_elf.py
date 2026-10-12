#!/usr/bin/env python3
"""Conservative linked-ELF ISA audit using GNU RISC-V binutils.
Checks metadata and decoded executable sections, not reachability or dynamic code.
"""
import argparse,json,os,re,struct,subprocess
from pathlib import Path
from software_profile import load_profile
GROUPS={
'i':set('lui auipc jal jalr beq bne blt bge bltu bgeu lb lh lw lbu lhu sb sh sw addi slti sltiu xori ori andi slli srli srai add sub sll slt sltu xor srl sra or and fence ecall ebreak'.split()),
'm':set('mul mulh mulhsu mulhu div divu rem remu'.split()),
'c':set('c.addi4spn c.lw c.sw c.nop c.addi c.jal c.li c.addi16sp c.lui c.srli c.srai c.andi c.sub c.xor c.or c.and c.j c.beqz c.bnez c.slli c.lwsp c.jr c.mv c.ebreak c.jalr c.add c.swsp'.split()),
'zicsr':set('csrrw csrrs csrrc csrrwi csrrsi csrrci'.split()),'zifencei':{'fence.i'},
'zbb':set('andn orn xnor clz ctz cpop min minu max maxu sext.b sext.h zext.h rol ror rori orc.b rev8'.split()),
'zbc':set('clmul clmulh clmulr'.split()),'zbs':set('bclr bclri bext bexti binv binvi bset bseti'.split())}
VERSIONS={'i':(2,1),'m':(2,0),'c':(2,0),'zicsr':(2,0),'zifencei':(2,0),'zicntr':(2,0),'zbb':(1,0),'zbc':(1,0),'zbs':(1,0),'zmmul':(1,0),'zca':(1,0)}
def extensions(isa):
    parts=isa.split('_');return set(parts[0][4:])|set(parts[1:])
def audit_header(data,profile):
    if len(data)<52 or data[:7]!=b'\x7fELF\x01\x01\x01':raise ValueError('Expected ELF32 little-endian version 1')
    h=struct.unpack_from('<HHIIIIIHHHHHH',data,16)
    if h[0]!=2 or h[1]!=243 or h[2]!=1:raise ValueError('Expected linked RISC-V ET_EXEC')
    if h[6]&~1:raise ValueError('Unsupported ELF ABI flags (float/RVE/TSO/unknown)')
    if h[6]&1 and 'c' not in extensions(profile['isa']):raise ValueError('ELF requires C extension')
    if h[7]!=52:raise ValueError('Invalid ELF header size')
    return h[3]
def audit_attributes(text,profile):
    arches=re.findall(r'Tag_RISCV_arch:\s*"([^"]+)"',text)
    if not arches:raise ValueError('Missing Tag_RISCV_arch; cannot verify ISA contract')
    allowed=extensions(profile['isa'])
    if 'm' in allowed:allowed.add('zmmul')
    if 'c' in allowed:allowed.add('zca')
    for arch in arches:
        if not arch.startswith('rv32'):raise ValueError('Non-RV32 architecture attribute')
        tokens=arch[4:].split('_')
        for token in tokens:
            match=re.fullmatch(r'([a-z][a-z0-9]*?)(\d+)p(\d+)',token)
            if not match:raise ValueError('Unrecognized versioned extension '+token)
            name,major,minor=match.groups()
            if name not in allowed:raise ValueError('Unsupported required extension '+name)
            if (int(major),int(minor))>VERSIONS[name]:raise ValueError('Unsupported extension version '+token)
    stacks=re.findall(r'Tag_RISCV_stack_align:\s*(\d+)',text)
    if any(int(n)!=profile['stack_alignment_bytes'] for n in stacks):raise ValueError('Stack alignment attribute disagrees with profile')
    return arches
def audit_disassembly(text,profile):
    allowed=set().union(*(GROUPS.get(e,set()) for e in extensions(profile['isa'])))|{'mret','wfi'}
    count=0;errors=[]
    # GNU -d -z -M no-aliases,numeric: canonical mnemonic and a hex instruction word.
    for line in text.splitlines():
        m=re.match(r'^\s*([0-9a-fA-F]+):\s+([0-9a-fA-F]+)\s+(\S+)',line)
        if not m:continue
        address,raw,name=m.groups()
        if name in ('.word','.2byte','.4byte','.8byte','.byte','.short'):
            errors.append(f'0x{address}: undecoded instruction/data ({name})');continue
        if len(raw) not in (4,8):errors.append(f'0x{address}: unsupported instruction width');continue
        word=int(raw,16);width=2 if len(raw)==4 else 4
        if (word&3!=3)!=(width==2):errors.append(f'0x{address}: inconsistent instruction width');continue
        if name=='pack' and word&0xfff0707f==0x08004033:name='zext.h'
        if name.startswith('c.')!=(width==2):errors.append(f'0x{address}: mnemonic/width mismatch');continue
        if name not in allowed:errors.append(f'0x{address}: unsupported instruction {name}');continue
        # Reject reserved encodings that binutils sometimes prints as hints.
        if width==4 and name in ('slli','srli','srai','rori','bclri','bexti','binvi','bseti') and word&(1<<25):
            errors.append(f'0x{address}: reserved RV32 immediate shift/bit encoding');continue
        count+=1
    if errors:raise ValueError('\n'.join(errors[:20]))
    if not count:raise ValueError('No decoded instructions; executable-section audit unavailable')
    return count
def tool_output(command):
    env=os.environ.copy();env['LC_ALL']='C'
    r=subprocess.run(command,text=True,capture_output=True,env=env)
    if r.returncode:raise ValueError('Binutils failed: '+r.stderr.strip())
    return r.stdout
def check(path,profile,readelf,objdump):
    entry=audit_header(path.read_bytes(),profile)
    arches=audit_attributes(tool_output([readelf,'-A',str(path)]),profile)
    count=audit_disassembly(tool_output([objdump,'-d','-z','-M','no-aliases,numeric',str(path)]),profile)
    return {'file':str(path),'entry':entry,'architecture_attributes':arches,'instructions_checked':count,'status':'pass','scope':'ELF ABI/ISA attributes and GNU-decoded executable sections; not reachability, dynamic code, platform legality or compliance proof'}
if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('elf',type=Path);p.add_argument('--profile',type=Path);p.add_argument('--readelf',default=os.environ.get('RISCV_READELF','riscv64-unknown-elf-readelf'));p.add_argument('--objdump',default=os.environ.get('RISCV_OBJDUMP','riscv64-unknown-elf-objdump'));p.add_argument('--report',type=Path);a=p.parse_args()
    try:
        result=check(a.elf,load_profile(a.profile) if a.profile else load_profile(),a.readelf,a.objdump)
        if a.report:a.report.parent.mkdir(parents=True,exist_ok=True);a.report.write_text(json.dumps(result,indent=2)+'\n')
        print(json.dumps(result))
    except (ValueError,OSError,KeyError) as e:p.exit(1,'ELF compatibility check failed: '+str(e)+'\n')
