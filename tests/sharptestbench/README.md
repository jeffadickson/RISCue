# RISCue / SharpTestBench CPU verification pilot

The RISCue repository now owns a C# SharpTestBench retirement scoreboard.
The RTL wrapper reuses the existing tests/tb_pipeline_smoke.sv program image.
The C# test checks 20 expected retirement PC, register and result triples,
requires the expected trap, rejects hardware fatal state, and enforces a timeout.

The initial configuration is ECC (RF_TMR=0). TMR, firmware/smoke mailbox, UART
and AXI workloads are follow-up milestones.

## Three initial CI execution paths

1. Original Icarus HDL self-checking regression.
2. Managed C# SharpTestBench retirement test on Icarus using the existing
   cocotb-derived GPI bridge. This is not yet fully cocotb-free.
3. Native Verilator C++ model running the original self-checking HDL fixture.
   This is cocotb-free but does NOT yet exercise the C# scoreboard or
   directly access generated model ports.

These initial paths must demonstrate correct retirement behavior. Wall times are
not apples-to-apples benchmark evidence; compilation and test-driver differences
must be eliminated first.

## Next
Qualify CI, run the same C# scoreboard through a truly independent native
backend, then profile RISCue running compiled-C smoke firmware. Measure
retired instructions, callbacks, signal widths and bytes, managed allocations,
and build-excluded simulation time. No performance claim before matched traces.
