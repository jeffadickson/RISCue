"""Cocotb parity test for RISCue's SharpTestBench 20-retirement CPU fixture."""
import json
import os
import time
import cocotb
from cocotb.triggers import FallingEdge, Timer

EXPECTED = [
 (0,1,7),(4,2,3),(8,3,21),(12,4,2),(16,5,1),
 (20,0,0),(24,6,21),(28,7,28),(32,8,3),(34,9,7),
 (38,0,0),(40,10,256),(44,0,0),(48,0,0),
 (256,20,11),(260,21,48),(264,21,52),(268,0,0),(272,0,0),
 (52,11,99)
]

@cocotb.test()
async def pipeline_retirements(d):
    observed=[]
    saw_trap=False
    start=time.perf_counter_ns()
    for cycle in range(2000):
        await FallingEdge(d.clk)
        # HDL test samples on falling edge; no driving from cocotb.
        await Timer(1, unit="ps")
        assert int(d.fatal.value)==0, f"fatal cycle {cycle}"
        if int(d.trap.value):
            assert int(d.trap_cause.value)==11
            saw_trap=True
        if int(d.retire_valid.value):
            row=(int(d.retire_pc.value),int(d.retire_rd.value),int(d.retire_result.value))
            n=len(observed)
            assert n<len(EXPECTED), "extra retirement"
            assert row==EXPECTED[n], f"retirement {n}: {row} != {EXPECTED[n]}"
            observed.append(row)
            if len(observed)==len(EXPECTED):
                assert saw_trap, "missing expected trap"
                elapsed_ms=(time.perf_counter_ns()-start)/1e6
                print(f"RISCUE_COCOTB_PASS retirements={n+1} cycle={cycle+1} test_body_ms={elapsed_ms:.6f}",flush=True)
                path=os.getenv("RISCUE_COCOTB_TRACE")
                if path:
                    with open(path,"w",encoding="utf-8") as f: json.dump(observed,f)
                return
    assert False, f"timeout: {len(observed)} retirements"
