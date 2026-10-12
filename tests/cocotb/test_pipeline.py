"""Directed pipeline/platform/fault tests. No legacy fail-stop trap assumption."""
import os
import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles,FallingEdge,Timer
TMR=os.environ.get('RF_TMR')=='1'
def encode(data):
    parity={1,2,4,8,16,32};c=0;j=0
    for pos in range(1,39):
        if pos not in parity:c|=((data>>j)&1)<<(pos-1);j+=1
    for p in parity:
        c|=(sum((c>>(pos-1))&1 for pos in range(1,39) if pos&p)%2)<<(p-1)
    return c|((c.bit_count()%2)<<38)
def i(rd,rs,imm,f=0,op=0x13):return ((imm&4095)<<20)|(rs<<15)|(f<<12)|(rd<<7)|op
def r(rd,a,b,f=0,f7=0):return (f7<<25)|(b<<20)|(a<<15)|(f<<12)|(rd<<7)|0x33
def st(rs,base,off,f=2):return ((off&0xfe0)<<20)|(rs<<20)|(base<<15)|(f<<12)|((off&31)<<7)|0x23
def csr(addr,rd,rs,f=1):return (addr<<20)|(rs<<15)|(f<<12)|(rd<<7)|0x73
def jal(rd,off):
    off&=0x1fffff
    return ((off>>20)<<31)|(((off>>1)&1023)<<21)|(((off>>11)&1)<<20)|(((off>>12)&255)<<12)|(rd<<7)|0x6f
async def start(d):
    d.rst_n.value=0;d.external_irq.value=0;d.fi_valid.value=0;d.fi_target.value=0;d.fi_index.value=0;d.fi_mask.value=0
    cocotb.start_soon(Clock(d.clk,10,unit='ns').start())
    await ClockCycles(d.clk,3)
async def boot(d,words=None,data=None,handler=None):
    d.rst_n.value=0;d.fi_valid.value=0;d.external_irq.value=0
    await ClockCycles(d.clk,3);await FallingEdge(d.clk)
    image=bytearray(len(d.soc.ram.mem)*4)
    if words:
        for n,w in enumerate(words):image[n*4:n*4+4]=w.to_bytes(4,'little')
    if data:image[:len(data)]=data
    if handler:
        for n,w in enumerate(handler):image[0x100+n*4:0x104+n*4]=w.to_bytes(4,'little')
    for n in range(len(d.soc.ram.mem)):d.soc.ram.mem[n].value=encode(int.from_bytes(image[n*4:n*4+4],'little'))
    await Timer(1,unit='ns');d.rst_n.value=1
async def retired(d,stop_pc,budget=4000):
    rows=[]
    for _ in range(budget):
        await FallingEdge(d.clk)
        assert not int(d.fatal.value),'hardware fatal before completion'
        if int(d.retire_valid.value):
            row=(int(d.retire_pc.value),int(d.retire_rd.value),int(d.retire_result.value),int(d.retire_insn.value));rows.append(row)
            if row[0]==stop_pc:return rows
    raise AssertionError(f'No retirement at {stop_pc:#x}; pc={int(d.pc.value):#x}')
def last_values(rows):return {rd:value for pc,rd,value,raw in rows if rd}
async def inject(d,target,index,mask):
    await FallingEdge(d.clk);d.fi_target.value=target;d.fi_index.value=index;d.fi_mask.value=mask;d.fi_valid.value=1
    await Timer(1,unit='ns');assert int(d.fi_ack.value)
    await ClockCycles(d.clk,1);await FallingEdge(d.clk);d.fi_valid.value=0
@cocotb.test()
async def forwarding_load_use_and_multicycle_m(d):
    await start(d)
    words=[i(1,0,7),i(2,0,3),r(3,1,2,0,1),r(4,1,2,4,1),r(5,1,2,6,1),st(3,0,0x300),i(6,0,0x300,2,3),r(7,6,1),st(2,0,0x301,0),i(8,0,0x301,4,3),i(9,0,99),jal(0,0)]
    await boot(d,words);v=last_values(await retired(d,40))
    assert {k:v[k] for k in range(1,10)}=={1:7,2:3,3:21,4:2,5:1,6:21,7:28,8:3,9:99}
@cocotb.test()
async def compressed_straddling_fetch(d):
    await start(d)
    data=(0x408d).to_bytes(2,'little')+i(2,1,4).to_bytes(4,'little')+(0x908a).to_bytes(2,'little')+(0x0001).to_bytes(2,'little')+i(3,1,1).to_bytes(4,'little')+jal(0,0).to_bytes(4,'little')
    await boot(d,data=data);rows=await retired(d,10);v=last_values(rows)
    assert v[1]==10 and v[2]==7 and v[3]==11
    assert [row[0] for row in rows]==[0,2,6,8,10]
    assert rows[0][3]==0x408d and rows[2][3]==0x908a
@cocotb.test()
async def precise_traps_and_mret(d):
    await start(d)
    handler=[csr(0x342,20,0,2),csr(0x341,21,0,2),csr(0x343,22,0,2),i(21,21,4),csr(0x341,0,21),0x30200073]
    words=[i(1,0,0x100),csr(0x305,0,1),0xffffffff,i(7,0,23),0x73,i(8,0,17),0x100073,i(9,0,99),i(10,0,1,2,3),st(7,0,1),0x000102b7,i(11,5,0,2,3),i(12,0,123),jal(0,0)]
    await boot(d,words,handler=handler);rows=await retired(d,48)
    causes=[value for pc,rd,value,raw in rows if rd==20]
    assert causes==[2,11,3,4,6,5]
    v=last_values(rows);assert v[7]==23 and v[8]==17 and v[9]==99 and v[12]==123
    assert not int(d.halted.value)
@cocotb.test()
async def csr_suppression_counters_and_fence_i(d):
    await start(d)
    words=[i(1,0,0x55),csr(0x340,2,1),csr(0x340,3,0,2),csr(0x340,0,0,3),csr(0x340,4,0,2),csr(0xc00,5,0,2),csr(0xc02,6,0,2),0x02a002b7,i(5,5,0x393),st(5,0,48),0x0000100f,jal(0,4),i(7,0,1),jal(0,0)]
    # 0x02a00393 is ADDI x7,x0,42, assembled in x5 and stored over old code.
    await boot(d,words);v=last_values(await retired(d,48))
    assert v[2]==0 and v[3]==0x55 and v[4]==0x55 and v[6]>=5 and v[7]==42
@cocotb.test()
async def external_interrupt_boundary(d):
    await start(d)
    words=[i(1,0,0x100),csr(0x305,0,1),i(2,0,-2048),csr(0x304,0,2),csr(0x300,0,8,6),i(10,10,1),jal(0,-4)]
    handler=[csr(0x342,20,0,2),csr(0x304,0,0),0x30200073]
    await boot(d,words,handler=handler);await retired(d,20)
    d.external_irq.value=1
    for _ in range(1000):
        await FallingEdge(d.clk)
        if int(d.trap.value):d.external_irq.value=0;break
    else:raise AssertionError('IRQ not taken')
    v=last_values(await retired(d,0x108));assert v[20]==0x8000000b
    await retired(d,20)
@cocotb.test()
async def protected_state_and_memory_injection(d):
    await start(d);await boot(d,[jal(0,0)]);await retired(d,0)
    await inject(d,2 if TMR else 1,20,1);await ClockCycles(d.clk,40)
    assert not int(d.fatal.value)
    if TMR:assert int(d.disagreement_count.value)>0
    else:assert int(d.corrected_count.value)>0
    for window in range(8):
        await inject(d,5,window,1);await ClockCycles(d.clk,12);assert not int(d.fatal.value)
    await inject(d,15,0,1);await ClockCycles(d.clk,12);assert not int(d.fatal.value)
    await inject(d,8,900,1);await ClockCycles(d.clk,8000);assert not int(d.fatal.value)
    await inject(d,8,900,3);await ClockCycles(d.clk,8000)
    assert int(d.fatal.value) and int(d.uncorrectable_count.value)>0

@cocotb.test()
async def clint_and_counter_rollover(d):
    await start(d)
    words=[0x0200c1b7,i(3,3,-8),i(2,0,-16),st(0,3,4),st(2,3,0)]
    words += [i(0,0,0)]*12
    words += [i(4,3,4,2,3),0x02000337,i(7,0,1),st(7,6,0,0),i(8,6,0,2,3),st(0,6,0,0),csr(0x344,9,0,2)]
    words += [csr(0xb80,0,0),csr(0xb00,0,2)]+[i(0,0,0)]*12+[csr(0xc80,10,0,2)]
    words += [i(1,0,1),csr(0xb82,0,1),csr(0xb02,0,2)]+[i(0,0,0)]*20+[csr(0xc82,11,0,2)]
    stop=(len(words)-1)*4;words+=[jal(0,0)]
    await boot(d,words);v=last_values(await retired(d,stop))
    assert v[4]>=1 and v[8]==1 and v[9]&8==0 and v[10]>=1 and v[11]==2

@cocotb.test()
async def software_and_timer_interrupt_priority(d):
    await start(d)
    handler=[csr(0x342,20,0,2),csr(0x304,0,0),0x30200073]
    for software in (1,0):
        words=[i(1,0,0x100),csr(0x305,0,1),0x020042b7,st(0,5,0),st(0,5,4),0x02000337,i(7,0,software),st(7,6,0),i(2,0,-1912),csr(0x304,0,2),csr(0x300,0,8,6),i(10,10,1),jal(0,-4)]
        # -1912 has low supported bits 0x888: external/software/timer enables.
        await boot(d,words,handler=handler)
        v=last_values(await retired(d,0x108))
        assert v[20]==(0x80000003 if software else 0x80000007)
        await retired(d,44)

@cocotb.test()
async def randomized_integer_retirement_reference(d):
    import random
    await start(d);rng=random.Random(0x52495343);regs=[0]*32;words=[];expected=[]
    def signed(x):return x if x<0x80000000 else x-0x100000000
    for n in range(120):
        rd=rng.randrange(1,16);a=rng.randrange(16);b=rng.randrange(16)
        if n<16 or rng.randrange(4)==0:
            imm=rng.randrange(-2048,2048);word=i(rd,a,imm);value=regs[a]+imm
        else:
            f=rng.randrange(8);m=rng.randrange(3)==0;f7=1 if m else (0x20 if f in (0,5) and rng.randrange(2) else 0)
            word=r(rd,a,b,f,f7);av=regs[a];bv=regs[b];sa=signed(av);sb=signed(bv)
            if m:
                q=-1 if bv==0 else (-1 if (sa<0)^(sb<0) else 1)*(abs(sa)//abs(sb))
                value=[av*bv,(sa*sb)>>32,(sa*bv)>>32,(av*bv)>>32,q,0xffffffff if bv==0 else av//bv,sa if bv==0 else sa-q*sb,av if bv==0 else av%bv][f]
            else:
                value=[av-bv if f7 else av+bv,av<<(bv&31),int(sa<sb),int(av<bv),av^bv,sa>>(bv&31) if f7 else av>>(bv&31),av|bv,av&bv][f]
        value &= 0xffffffff;regs[rd]=value;expected.append((n*4,rd,value,word));words.append(word)
    words.append(jal(0,0));await boot(d,words)
    assert await retired(d,(len(expected)-1)*4,budget=12000)==expected


@cocotb.test(skip=os.environ.get('PIPELINE_UPSTREAM')!='1')
async def pinned_upstream_programs(d):
    import json,hashlib
    from pathlib import Path
    root=Path(os.environ['PROJECT_ROOT'])
    manifest=json.loads((root/'build/pipeline-upstream/manifest.json').read_text())
    await start(d)
    for record in manifest['programs']:
        data=(root/record['binary']).read_bytes()
        assert hashlib.sha256(data).hexdigest()==record['sha256']
        assert len(data)<=len(d.soc.ram.mem)*4
        await boot(d,data=data)
        for _ in range(record['max_cycles']):
            await FallingEdge(d.clk)
            assert not int(d.fatal.value),record['name']+' hardware fatal'
            if int(d.trap.value):
                assert int(d.trap_cause.value)==3,record['name']+' unexpected architectural trap'
                if TMR:
                    a=int(d.soc.core.tmr0[10].value);b=int(d.soc.core.tmr1[10].value);c=int(d.soc.core.tmr2[10].value)
                    value=(a&b)|(a&c)|(b&c)
                else:
                    code=int(d.soc.core.rf[10].value)
                    value=sum(((code>>(p-1))&1)<<j for j,p in enumerate(p for p in range(1,39) if p not in {1,2,4,8,16,32}))
                assert value==record['pass_value'],record['name']+' software failure '+str(value)
                break
        else:raise AssertionError(record['name']+' timeout')

@cocotb.test()
async def direct_jump_links_wrong_paths_and_trap_priority(d):
    await start(d)
    words=[i(5,0,0x100),csr(0x305,0,5),jal(1,12),st(0,0,0x340),0xffffffff,
           0x90022021,0xffffffff,0x9002a021,0xffffffff,
           i(2,0,3),i(2,2,-1),0x00010463,jal(0,-8),0x73,jal(3,8),0xffffffff,
           i(4,3,1),0xffffffff,jal(6,8),0xffffffff,i(7,6,1)]
    handler=[csr(0x342,20,0,2),csr(0x341,21,0,2),i(21,21,4),csr(0x341,0,21),0x30200073]
    await boot(d,words,handler=handler)
    rows=await retired(d,80)
    expected=[0,4,8,20,28,36,40,44,48,40,44,48,40,44,52,256,260,264,268,272,56,64,68,256,260,264,268,272,72,80]
    assert [row[0] for row in rows]==expected
    assert [(pc,rd,v) for pc,rd,v,raw in rows if pc in (8,20,56,64,72,80)]==[(8,1,12),(20,1,22),(56,3,60),(64,4,61),(72,6,76),(80,7,77)]
    assert [v for pc,rd,v,raw in rows if rd==20]==[11,2]
    # Speculative fall-through store at PC12 must never execute.
    assert int(d.soc.ram.mem[0x340//4].value)==encode(0)

@cocotb.test()
async def bitmanip_retirement_and_dependencies(d):
    import random,sys
    from pathlib import Path
    sys.path.insert(0,str(Path(os.environ['PROJECT_ROOT'])/'tools'))
    from bitmanip_vectors import NAMES,IMM,instruction,reference
    await start(d);rng=random.Random(0xBBBCCB5)
    def constant(rd,x):
        upper=(x+0x800)&0xfffff000
        return [upper|(rd<<7)|0x37,i(rd,rd,x&4095)]
    # Chunked programs avoid the trap handler at 0x100 and stress forwarding,
    # a load-use hazard, x0 suppression and store data from each extension.
    for name in NAMES:
        d._log.info('bitmanip instruction %s',name)
        cases=[(0,0),(0x80000000,31),(0xffffffff,0xffffffff),(0x00800080,32)]
        cases += [(rng.getrandbits(32),rng.getrandbits(32)) for _ in range(4)]
        words=[];expected={}
        for a,b in cases:
            words+=constant(1,a)+constant(2,b)
            words += [st(1,0,0x300),i(1,0,0x300,2,3)]
            pc=len(words)*4;words += [instruction(name,3,1,2,b&31)]
            value=reference(name,a,b);expected[pc]=(3,value)
            pc=len(words)*4;words += [i(4,3,1)];expected[pc]=(4,(value+1)&0xffffffff)
            words += [st(3,0,0x304),i(5,0,0x304,2,3)]
            expected[(len(words)-1)*4]=(5,value)
            words += [instruction(name,0,1,2,b&31),i(6,0,7)]
            expected[(len(words)-1)*4]=(6,7)
        stop=(len(words)-1)*4;words+=[jal(0,0)]
        await boot(d,words);rows=await retired(d,stop)
        for pc,rd,result,raw in rows:
            if pc in expected:assert (rd,result)==expected[pc],(name,pc,result,expected[pc])
        assert set(expected)<=set(row[0] for row in rows)

@cocotb.test()
async def bitmanip_reserved_encoding_traps(d):
    import sys
    from pathlib import Path
    sys.path.insert(0,str(Path(os.environ['PROJECT_ROOT'])/'tools'))
    from bitmanip_vectors import vectors
    await start(d)
    illegal=[w for w,a,b,v,bad in vectors() if bad]
    handler=[csr(0x342,20,0,2),csr(0x341,21,0,2),csr(0x343,22,0,2),i(21,21,4),csr(0x341,0,21),0x30200073]
    words=[i(1,0,0x100),csr(0x305,0,1)]+illegal+[i(7,0,99),jal(0,0)]
    await boot(d,words,handler=handler);rows=await retired(d,(len(words)-2)*4)
    assert [v for pc,rd,v,w in rows if rd==20]==[2]*len(illegal)
    assert [v for pc,rd,v,w in rows if rd==22]==illegal
    assert last_values(rows)[7]==99

@cocotb.test(skip=not os.path.exists(os.path.join(os.environ.get('PROJECT_ROOT','.'),'build/c-smoke/metadata.json')))
async def compiled_c_smoke(d):
    import json
    from pathlib import Path
    root=Path(os.environ['PROJECT_ROOT']);folder=root/'build/c-smoke'
    if not (folder/'metadata.json').exists():
        raise AssertionError('Run make c-smoke-build before compiled_c_smoke')
    meta=json.loads((folder/'metadata.json').read_text())
    import hashlib
    assert hashlib.sha256((folder/'smoke.bin').read_bytes()).hexdigest()==meta['binary_sha256'],'Stale C build metadata'
    await start(d);await boot(d,data=(folder/'smoke.bin').read_bytes())
    cycles=0;retirements=0;used=set()
    for _ in range(12000):
        await FallingEdge(d.clk);cycles+=1
        assert not int(d.fatal.value),'C workload hardware fatal'
        assert not int(d.trap.value),'C workload unexpected trap'
        if int(d.retire_valid.value):
            retirements+=1;used.add(int(d.retire_insn.value))
            if int(d.retire_pc.value)==meta['finish_pc']:break
    else:raise AssertionError('C workload did not finish')
    def decode(code):
        parity={1,2,4,8,16,32};bits=[(code>>(pos-1))&1 for pos in range(1,39) if pos not in parity]
        return sum(bit<<j for j,bit in enumerate(bits))
    values=[decode(int(d.soc.ram.mem[0xfc0//4+j].value)) for j in range(9)]
    x=0x12345678;product=0
    for j in range(32):
        if (0x1021>>j)&1:product^=x<<j
    expected=[0x50415353,1496,213,5,((x>>7)|(x<<25))&0xffffffff,x.bit_count(),product&0xffffffff,x|0x80000000,256]
    assert values==expected,(values,expected)
    result={'mode':'tmr' if TMR else 'ecc','cycles':cycles,'retirements':retirements,'mailbox':values,'expected':expected,'status':'pass','binary_sha256':meta['binary_sha256']}
    (folder/('result-tmr.json' if TMR else 'result-ecc.json')).write_text(json.dumps(result,indent=2)+'\n')
    d._log.info('Compiled C PASS: %s',result)

@cocotb.test(skip=os.environ.get('PIPELINE_C_WORKLOAD')!='1' or not os.path.exists(os.path.join(os.environ.get('PROJECT_ROOT','.'),'build/c-workload/metadata.json')))
async def compiled_c_workload(d):
    import csv,hashlib,json,re,sys,time
    from collections import Counter
    from pathlib import Path
    root=Path(os.environ['PROJECT_ROOT']);folder=root/'build/c-workload';sys.path.insert(0,str(root/'tools'))
    from workload_reference import expected
    meta=json.loads((folder/'metadata.json').read_text());binary=(folder/'smoke.bin').read_bytes()
    assert hashlib.sha256(binary).hexdigest()==meta['binary_sha256']
    names={int(m[1],16):m[2] for line in (folder/'smoke.dis').read_text().splitlines() if (m:=re.match(r'^\s*([0-9a-f]+):\s+[0-9a-f]+\s+(\S+)',line))}
    symbols=sorted((address,name) for name,address in meta['symbols'].items());ranges=[(address,name,symbols[n+1][0] if n+1<len(symbols) else 0xffffffff) for n,(address,name) in enumerate(symbols)]
    await start(d);await boot(d,data=binary)
    started=time.monotonic();hist=Counter();functions=Counter();rows=[];interrupts=[];minimum_sp=0x1e00
    for cycle in range(1,60001):
        await FallingEdge(d.clk)
        assert not int(d.fatal.value),'workload integrity failure'
        if int(d.trap.value):
            cause=int(d.trap_cause.value);assert cause==0x80000007,('unexpected trap',cause,int(d.trap_value.value));interrupts.append({'cycle':cycle,'cause':cause})
        if int(d.retire_valid.value):
            pc=int(d.retire_pc.value);raw=int(d.retire_insn.value);rd=int(d.retire_rd.value);value=int(d.retire_result.value)
            mnemonic=names.get(pc,'unknown');assert mnemonic!='unknown',('unknown retired PC',pc)
            hist[mnemonic]+=1
            for start_pc,name,end in ranges:
                if start_pc<=pc<end:functions[name]+=1;break
            if rd==2 and 0x1000<=value<=0x1e00:minimum_sp=min(minimum_sp,value)
            rows.append((cycle,pc,raw,mnemonic,rd,value))
            if pc==meta['finish_pc']:break
    else:raise AssertionError('C workload timed out')
    assert len(interrupts)==1,interrupts
    def decode(code):
        positions=[p for p in range(1,39) if p not in (1,2,4,8,16,32)]
        return sum(((code>>(p-1))&1)<<j for j,p in enumerate(positions))
    values=[decode(int(d.soc.ram.mem[0x1f00//4+j].value)) for j in range(32)]
    reference=expected()
    for index,value in reference['mailbox'].items():assert values[index]==value,(index,values[index],value)
    assert values[25] in names,('IRQ resume PC is not an instruction boundary',values[25])
    assert all(values[n]>0 for n in (1,2,3,4,26,27))
    mode='tmr' if TMR else 'ecc'
    result={'mode':mode,'status':'pass','cycles':cycle,'retirements':len(rows),'cpi':cycle/len(rows),'simulation_clock_period_ns':10,'execution_time_at_reference_10MHz_us':cycle/10,'wall_seconds':time.monotonic()-started,'instruction_histogram':dict(sorted(hist.items())),'function_retirements':dict(functions),'compressed_retirements':sum(raw&3!=3 for _,_,raw,_,_,_ in rows),'interrupts':interrupts,'minimum_observed_sp':minimum_sp,'stack_bytes_observed':0x1e00-minimum_sp,'phase_cycles':dict(zip(['sort_including_irq','matrix','crc32','recursive_fibonacci'],values[1:5])),'mailbox':values,'reference':reference,'binary_sha256':meta['binary_sha256'],'fatal_count':int(d.fatal_count.value),'uncorrectable_count':int(d.uncorrectable_count.value),'corrected_count':int(d.corrected_count.value),'disagreement_count':int(d.disagreement_count.value)}
    (folder/('result-'+mode+'.json')).write_text(json.dumps(result,indent=2)+'\n')
    with (folder/('trace-'+mode+'.csv')).open('w') as f:
        writer=csv.writer(f);writer.writerow(['cycle','pc','raw_instruction','mnemonic','rd','result']);writer.writerows(rows)
    d._log.info('C workload PASS: mode=%s cycles=%d retirements=%d IRQ=%s phases=%s',mode,cycle,len(rows),interrupts,result['phase_cycles'])
