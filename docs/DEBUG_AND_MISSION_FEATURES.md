# Standard debug and mission-specific instruction priorities

## Debug module recommendation

Target the ratified RISC-V Debug Specification 1.0 with one hart, a Debug Module
(DM) and Debug Module Interface (DMI). An ARM AXI-to-DMI transport can serve the
KV260 wrapper; a JTAG DTM can serve independent lab tools. A transport alone
is not a conforming DM/hart implementation. Compatibility with an actual
OpenOCD/GDB release must be demonstrated, not inferred from a register map.

The first standard-debug implementation should include precise halt/resume,
resethalt request, dcsr/dpc, one-instruction stepping, abstract GPR and debug
CSR access, and appropriate dmcontrol/dmstatus/abstractcs/data registers.
Optional system-bus memory access must arbitrate through ECC memory and honor
transaction ownership. Hardware trigger/breakpoint support belongs to Sdtrig;
a program buffer and additional abstract CSR/memory commands are later scope.
A minimal subset must be advertised honestly rather than claiming full Debug
Specification support. Normal EBREAK must retain trap semantics unless the
debug configuration requests debug entry.

Debug halt must drain older accepted operations, suppress younger stores and
preserve a resumable architectural PC. A reset button cannot substitute for
it. Debug state, trigger state and command FSMs must be protected; critical
halt/resume controls need the same integrity discipline as normal pipeline
control. Define interrupt/exception/step priorities, timer/counter behavior,
and fail-stop recovery before implementation. Fault records should remain
inspectable after a hardware integrity failure; resume of untrusted state
must not silently clear the failure. Production debug access and injection
must be explicitly disabled or otherwise governed by the target.

The current ARM wrapper implements reset/run, loading, telemetry, IRQ and
fault campaigns. It does not implement dcsr/dpc, standard debug mode, DMI,
GDB breakpoints or single-stepping. Those are open requirements.

## Useful mission additions

Prefer standard extensions when useful: Zbb supplies basic bit manipulation
(counts, rotates, byte/sign operations, min/max); Zbs supplies single-bit
operations useful for packed registers/flags. Zbc supplies carryless multiply
for CRC and binary-field calculations. Their value is workload-dependent;
CRC polynomials, bit order and initialization must come from the mission ICD.
Zicond may reduce some unpredictable conditional sequences. None of these
extensions is implemented or advertised by the current profile.

A custom saturating fixed-point arithmetic instruction or a specific CRC
step can be worthwhile after profiling shows a concrete control/telemetry
bottleneck. Define exact arithmetic, signedness, saturation/overflow reporting,
CRC polynomial and bit order, timing, operand/result behavior, compiler
intrinsics, and independent golden/formal tests before assigning a custom
opcode. Saturation is not automatically safer: silent clipping can hide an
invalid control solution, so software must observe and handle it.

For radiation-tolerant control, bounded scrub/recovery, protected watchdogs,
error telemetry accessible to flight software, memory protection/partitioning,
interrupt timing analysis and recovery policy are more fundamental than
custom opcodes. They are mostly platform features, not new ISA instructions.
The current digital ECC/TMR mechanisms and laboratory tests do not establish
radiation qualification or common-mode/SET/configuration resilience.

Primary specifications:
- https://docs.riscv.org/reference/debug/v1.0/
- https://docs.riscv.org/reference/debug/v1.0/debug_module.html
- https://docs.riscv.org/reference/isa/unpriv/b-st-ext.html
- https://docs.riscv.org/reference/isa/v20260120/unpriv/zicond.html
