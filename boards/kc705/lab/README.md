# Instrumented KC705 fault campaigns

`make kc705-instrumented` builds the pipeline with FI enabled and VIO/ILA.
`make kc705-instrumented-synth` stops after synthesis. Use `make kc705-program
KC705_FI=1 KC705_INSTRUMENTED=1` explicitly to program that matching build.
No build command automatically connects to hardware or runs injections.
Vivado debug-IP generation, place/route and physical hardware operation have
not been run for this release. Keep the matching .bit and .ltx together.

From Vivado Hardware Manager, after selecting the intended programmed device:

```tcl
source boards/kc705/lab/hardware_lab.tcl
riscue::inject [dict create target 8 index 1023 mask 1 delay 20 count 8 gap 100 index_step 4294967295]
```

index_step is an unsigned 32-bit modular step; use `4294967295` for -1 in the
example above. Masks are hexadecimal without leading minus signs. Descriptors
are captured once at a request-token change; editing probes later cannot
change the captured campaign. The host disarms first, stages all fields,
arms ILA, arms the controller and toggles the token last. The FPGA schedules
each eligible injection edge and records receiver acknowledgement.

Trigger kinds: 0 immediate, 1 retired PC match, 2 debounced north-button pulse.
First injection is `delay` clocks after the eligible trigger edge; delay >=1.
Successive injections are `gap` clocks apart; gap >=2. Count is 1..65535.
Optional rotation rotates right within the target/window width. Index stepping
may hit a narrower final window or an invalid index; that terminates with an
error rather than applying an out-of-range mask. stop_on_fatal defaults true.
Disarm, reset or request-token changes abort busy campaigns. Board reset
baselines the current VIO token and cannot replay a retained descriptor.

Status codes: 0 success; 1 unarmed; 2 target/index; 3 mask; 4 schedule;
5 receiver rejected; 6 aborted/disarmed; 7 core fatal; 8 core reset;
9 token changed while busy; 10 controller state/no-majority error.
Controller state is triplicated, repaired and sticky disagreement reported.
VIO and ILA are lab diagnostics outside the radiation tolerance guarantee.

See `probe-map.json` for every VIO/ILA width. The 512-bit mask uses two
256-bit probes. ILA has depth 4096 and includes PC/retirement/detector counts,
FI request/acknowledgement and campaign timestamps. Capture trigger settings
are chosen in Hardware Manager; this script does not promise a particular
pre/posttrigger acquisition window.

`make kc705-inject` explicitly attaches to one connected XC7K325T, loads the
matching probe file and executes one injection; TARGET/INDEX/MASK can be set
with KC705_INJECT_TARGET, KC705_INJECT_INDEX, KC705_INJECT_MASK. A nonzero
campaign status exits with an error. JTAG defaults to 1 MHz. The script does
not program a new bitstream. Core reset retains SRAM; reprogram or reload the
memory to restore it after a destructive campaign.
