# Strict requirements and traceability — RISCue 0.4

Implemented describes available RTL/harnesses, not completed verification. Executed evidence is reported separately; open requirements remain open.

| ID | Requirement | Verification | Status |
| --- | --- | --- | --- |
| ISA-001 | The core shall implement every RV32I integer instruction and every RV32M operation in the declared unprivileged execution environment. | tb_exec; upstream_programs; tb_trace | implemented |
| ISA-002 | The core shall implement x0=0, little-endian loads/stores, signed/unsigned extensions, and precise alignment/illegal-instruction fail-stop trap outputs. | tb_soc; tb_exec; rv32ui load/store programs | implemented |
| ISA-003 | Unsupported C/A/F/D/Zicsr/Zifencei and privileged features shall be explicitly declared and never claimed as verified. | upstream manifest exclusions; README; review | implemented |
| MEM-001 | Each SRAM word shall store 32 data bits plus 7 SECDED bits; all single-bit positions shall correct and all double-bit pairs shall detect. | tb_ecc; stored_fault_campaign | implemented |
| MEM-002 | SRAM shall check and correct data before use and write corrected codewords back without a race with a foreground partial write. | tb_ram; tb_fault; stored_fault_campaign | implemented |
| MEM-003 | Detected uncorrectable load/read or partial-RMW data shall not be consumed or written as a new valid codeword. | tb_ram; tb_fault; fail-stop checks | implemented |
| MEM-004 | Background scrub arbitration shall have a specified worst-case service interval under continuous foreground traffic. | future saturation test and timing analysis | open |
| MEM-005 | Physical codeword interleaving and any stronger ECC shall be selected using target multi-cell-upset data. | target layout review and irradiation | target-dependent |
| MEM-006 | ECC initialization and boot-memory contents shall be valid before processor release from reset. | simulation loader tested; physical boot sequencer not implemented | partial |
| RF-001 | A static RF_TMR parameter shall select either 39-bit SECDED words or three independent 32-bit register replicas. | cocotb ecc/tmr build matrix; synthesis audit | implemented |
| RF-002 | ECC mode shall correct operands before use and repair every nonzero register within 31 background-scrub clocks. | stored_fault_campaign all x1–x31/code bits; tb_fault | implemented |
| RF-003 | TMR mode shall vote operands and repair all replicas after any one replica-bit upset, including x0 restoration. | stored_fault_campaign all x1–x31/replicas/data bits | implemented |
| RF-004 | TMR mode shall declare two-replica identical corruption outside the guaranteed correction model rather than claiming detection. | explicit limitation; future fault-characterization matrix | implemented |
| CTL-001 | PC, instruction, pending transaction, watchdog, halt/fault status and RF scrub pointer shall have triplicated voted state with repair feedback. | tb_fault; protected_state_and_reporting; synthesis audit | implemented |
| CTL-002 | The CPU FSM shall use explicit distance-four encodings and halt on an invalid voted state; correction shall be attributed to TMR, not to nonexistent Hamming decoding. | tb_fault; FSM encoding review | implemented |
| CTL-003 | RAM response, error/fatal state and scrub pointer shall be triplicated and repaired. | protected_state_and_reporting; synthesis audit | implemented |
| CTL-004 | Every sequential controller and stateful helper shall appear in a protection inventory, including newly added blocks. | STATE_MACHINE_AUDIT.md; requirement review | implemented |
| EXEC-001 | Two execution decision records shall agree before architectural writes or memory requests derived from execution are authorized. | tb_fault execution mismatch; synthesis audit | implemented |
| EXEC-002 | Shared decode/voter/commit logic and address-selection common modes shall be closed with target-specific mitigation before a radiation-tolerance claim. | netlist fault injection and physical implementation | open |
| BUS-001 | The reference receiver shall reject detected bad address/control/write-data codewords and out-of-range requests without committing a store. | tb_ram | implemented |
| BUS-002 | Requests shall be serialized and stalled transactions shall trigger a bounded fail-stop timeout. | tb_fault timeout; upstream runs | implemented |
| REP-001 | Detector observations shall produce sticky source flags and saturating corrected/uncorrectable/disagreement/fatal counters. | protected_state_and_reporting; reporter tests | implemented |
| REP-002 | The recorder shall preserve first and last observation PC/address/flags, retaining the first record until reset. | protected_state_and_reporting | implemented |
| REP-003 | Recorder state shall be triplicated with repair and shall report its own replica disagreement. | protected_state_and_reporting all recorder bits; synthesis audit | implemented |
| REP-004 | Simultaneous-event metadata priority, repeated-detection counting, record loss, reset behavior and counter saturation shall be explicitly specified. | README reporting contract; reporter tests | implemented |
| FI-001 | Production FI_ENABLE=0 builds shall acknowledge no injection and retain normal behavior even if fault ports toggle. | test_interfaces.injection_qualification_and_reporting; synthesis review | implemented |
| FI-002 | Test builds shall expose deterministic clock-edge XOR injection for stored SRAM/RF/control/report state, with bounded indices and acknowledgement. | stored_fault_campaign; protected_state_and_reporting; hook rejection tests | implemented |
| FI-003 | Fault campaigns shall record mode, target, index, bit mask, expected outcome, and actual pass/fail with reproducible stimulus. | build/fault_results_*.json; JUnit XML; source deterministic order | implemented |
| FI-004 | No fault campaign shall describe stored-bit injection as validation of analog SET pulse widths, multiple-node strike coverage or clock/reset susceptibility. | PROTECTION.md; review | implemented |
| BUILD-001 | Upstream code shall be fetched at immutable commits specified by a lockfile; dirty or mismatched checkouts shall be rejected. | fetch_upstream.py; build_upstream.py checks | implemented |
| BUILD-002 | cocotb shall run upstream instruction/workload tests and fault campaigns in both register modes, with bounded test timeouts and nonzero failure exit status. | run_cocotb.py; results.xml; mode matrix | implemented |
| BUILD-003 | Synthesis shall preserve and audit separate sequential drivers for CPU/RAM/report TMR state and optional RF replicas, plus distinct execution instances. | audit_netlist.py; make synth-ecc/synth-tmr | implemented |
| QUAL-001 | Radiation qualification shall require target implementation, timing/CDC/reset analysis, representative irradiation and a mission-level residual error/outage budget. | future qualification plan | open |
| FV-001 | The project shall fetch formal sources at immutable commits and verify downloaded tool archives against SHA256 before execution. | upstream.lock.json; formal-tools.lock.json; formal-fetch; formal-tools | implemented |
| FV-002 | The ECC encoder/decoder shall have a combinational proof covering all data values and all single/double stored-bit faults. | formal-ecc; verification/evidence/formal | implemented |
| FV-003 | The error monitor shall have inductive checks for sticky observations, exact saturating counts, first/last records and repair of one corrupted replica. | formal-monitor; formal/monitor.sv | implemented |
| FV-004 | ISA checks shall use an optional RVFI interface and the pinned upstream RV32IM models; real M arithmetic shall not be silently replaced by ALTOPS. | formal-isa; formal-execute; formal/checks.cfg | implemented |
| FV-005 | Core and RAM fault harnesses shall state injection multiplicity, permitted locations, environment assumptions and cycle bounds. | formal-fault; formal-ram; docs/FORMAL.md | implemented |
| FV-006 | Every formal campaign shall retain per-job outcomes and counterexamples; FAIL, UNKNOWN, ERROR and TIMEOUT shall fail the command. | tools/run_formal.py; results-*.json | implemented |
| FV-007 | Reachability covers shall accompany directed fault scenarios and instruction checks to identify vacuous configurations. | formal cover jobs; tools/run_formal.py cover | implemented |
| FV-008 | Whole-core instruction and single-upset containment checks shall complete without unresolved jobs before whole-core formal verification is claimed. | formal-isa; formal-fault; verification/evidence/formal/summary.json | open |
| FV-009 | Bus/memory consistency, unbounded progress, completeness of decoded ISA coverage and equivalence with RVFI disabled shall be separately verified before broader certification claims. | additional formal harnesses | open |
| FPGA-001 | The KC705 target shall declare the verified board pin facts, clock conversion, FPGA part and initialization image configuration. | boards/kc705/README.md; kc705.xdc; UG810 review | implemented |
| FPGA-002 | The FPGA build shall preserve named replica groups and execution lanes and reject failed timing or error-level DRC before bitstream generation. | Vivado build.tcl; redundancy.rpt; timing.rpt; drc.rpt | implemented |
| FPGA-003 | Clock/reset and every board diagnostic controller shall be included in the protection inventory with their laboratory-only unprotected scope. | STATE_MACHINE_AUDIT.md; board README | implemented |
| FPGA-004 | The KC705 target shall complete synthesis, implementation, timing closure and on-board bring-up before operational FPGA support is claimed. | Vivado and KC705 hardware validation | open |
