# Verilator native model access versus VPI

## What the two interfaces are

**VPI (Verilog Procedural Interface)** is a standardized simulator API. A
verification client locates HDL objects by name or hierarchy, obtains opaque
handles, reads and writes values through calls such as `vpi_get_value` and
`vpi_put_value`, and schedules callbacks through `vpi_register_cb`.
The simulator must preserve its event scheduling, callbacks and value
representation at this boundary. This makes VPI useful across simulator
implementations, and suitable for HDL tests that need dynamic discovery.

**Verilator's native C++ model** is compiled directly from elaborated RTL.
A build invokes Verilator to emit a C++ design class (typically `V<top>`),
then compiles the generated code into an executable or library. A native
test harness can set exposed input ports, call `eval()` (and advance
simulated time / process events as appropriate), then read output ports
as native C++ values. Accessible internal objects may require explicit
Verilator pragmas or generation settings; arbitrary HDL objects are **not**
automatically part of a stable native C++ API.

Example (conceptual, for a zero-delay clocked top-level model):

```cpp
#include "Vcounter.h"
#include "verilated.h"

int main() {
    VerilatedContext context;
    Vcounter dut{&context};
    dut.clk = 0;
    dut.reset = 1;
    dut.enable = 1;
    dut.eval();
    dut.clk = 1;
    dut.eval();                 // evaluate the rising edge
    dut.clk = 0;
    dut.eval();
    context.timeInc(1);        // advance time when appropriate
    dut.reset = 0;
    // Repeat clock drive / eval / observe; check output values.
    dut.final();
}
```

This model intentionally omits delayed/timed RTL: designs using Verilator
`--timing` must also honor the generated scheduling interface and pending
timed events. A wrapper cannot assume that one `eval()` invocation represents
one entire HDL simulation timestep for every design.

## Why native model access can be much faster

| Aspect | Standard VPI / GPI | Direct Verilator C++ |
| --- | --- | --- |
| Discover a signal | Hierarchy traversal, handle lookup | Generated C++ field/accessor when exposed |
| Read/write signals | Simulator API and value buffers | Native loads/stores for supported ports |
| Cross-language boundary | FFI callback/value conversion per operation | No per-signal boundary for C++ client |
| Scheduling | Simulator callbacks and event regions | Direct calls to generated evaluator, explicit time handling |
| Dynamic HDL access | Broad, portable introspection | Compile-time-known signals; optional generated exposure |
| Compatibility | Multiple simulators | Tightly coupled to Verilator model/version/build |
| Four-state fidelity | Value formats may convey X/Z | Depends on Verilator two-state/four-state capabilities and chosen representation |

VPI isn't inherently slow in every application. Handle caching, batched
transfers, direct packed-vector transport and callbacks can remove much
of the avoidable overhead. Native access tends to have the largest
advantage when **many short signal operations** happen per timestep
and the same signals can be exposed as typed generated fields.

Conversely, generating C++ does not make a managed C# verification
client magically native. C# still needs a correct **stable C ABI**
(or similar managed/native bridge) for model creation, clock/eval,
typed reads/writes, event/timer callbacks, lifecycle and errors.
A good bridge batches accesses and minimizes transitions; a C++ helper
or code-generated accessors are particularly useful for large signal
vectors and tightly coupled interface transactions.

## What the existing RISCue evidence actually demonstrates

The RISCue CI workflow `sharptestbench.yml` already builds the
self-checking SystemVerilog CPU smoke test using Verilator
`--binary --timing`. Its compiled executable runs the **HDL testbench**
itself. There is no C# scoreboard or direct C++ port-access harness
in that job. This proves the native compiled HDL execution path works,
**not** that SharpTestBench has completed the new native Verilator backend.

The first CI timing experiment used **20 retirements over 165 clocks**,
with 150 independent executable launches per simulator. Results from
that specific Ubuntu runner were:

- Verilator: median about **1.698 ms per process**.
- Icarus `vvp`: median about **1,034.698 ms per process**.
- Apparent ratio: about **609×** for *process elapsed time*.

Both paths checked the same HDL retirement oracle. The time includes
process startup, simulator initialization and shutdown; it excludes
compilation. The workload is far too short to measure steady-state
simulator throughput reliably. Crucially, neither path benchmarks
SharpTestBench's C# execution through GPI. **Do not report 609× as
the native interface speedup over VPI or cocotb.**

A separate CI job is being added for a cocotb Python scoreboard using
the same RISCue smoke fixture. It must pass on Icarus/Verilator before
any comparison is interpreted. The C# SharpTestBench integration job
is still a distinct qualification target.

## Next meaningful performance experiment

1. Use one compiled-C RISCue program and the same architectural
   retirement, trap, final signature and trace checks in all modes.
2. Define comparable interfaces and test duties for standalone HDL,
   cocotb VPI/GPI, SharpTestBench GPI and SharpTestBench native Verilator.
3. Capture retired instruction count, actual simulated clocks, simulator
   version, interface operation counts, and trace hashes.
4. Time prebuilt model execution separately from process startup,
   compilation, managed runtime initialization and teardown.
5. Repeat enough times for distributions/medians, recording CPU and
   runner conditions; report both whole-test wall time and steady-state
   cycles/second where it can be measured meaningfully.
6. Do not claim independent C# native access until it runs the *same*
   test assembly with the *same* observable semantics and results.

## External interface references

- Verilator native model / connecting C++:
  https://verilator.org/guide/latest/connecting.html
- Verilator executable and timing options:
  https://verilator.org/guide/latest/exe_verilator.html
- IEEE VPI interface background in Icarus:
  https://steveicarus.github.io/iverilog/usage/vpi.html
- SharpTestBench detailed HTML lesson:
  https://github.com/jeffadickson/SharpTestBench/blob/feature/native-dotnet-consumer-runner/docs/VPI_AND_NATIVE_SIMULATOR_INTERFACES.html
