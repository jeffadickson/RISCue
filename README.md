# RISCue

A KV260 ARM/AXI lab target now includes a program loader, browser dashboard, telemetry, IRQ and hardware injection controls. See [KV260 setup](boards/kv260/README.md), [C software contract](docs/SOFTWARE_ABI.md), and [standard debug / mission priorities](docs/DEBUG_AND_MISSION_FEATURES.md). Generic AXI simulation passes; Vivado/Linux/physical board validation and standard debug implementation are pending.

Version 0.5.2 adds compared direct-jump target lanes and ID-stage JAL/C.J/C.JAL redirection. `make pipeline-jump` compares early/late resolution in ECC/TMR modes. The 30-instruction short test takes 144 versus 172 clocks; full-workload performance and formal results remain pending.

Short SV simulations now pass for ECC/TMR pipeline smoke (20 retirements, 165 clocks), multicycle arithmetic (2,088 vectors plus cancellation/repair), and hardware injection scheduling. See verification/pipeline-smoke-results.json. Full cocotb/upstream/formal/Vivado/board validation remains pending. Older compile-only statements below describe the initial implementation checkpoint.

**0.5 pipeline target:** KC705 now selects `riscue_pipeline_soc`, an
implemented RV32IMC_Zicsr_Zifencei_Zicntr M-only five-stage core with CLINT,
precise traps, interrupts, and multicycle arithmetic. New simulations,
formal proofs, Vivado builds and board testing are pending; historical results
below concern the preserved legacy serialized core. See
[the pipeline design/status](docs/PIPELINE_IMPLEMENTATION.md),
[STRIDE and fault model](docs/STRIDE.md), and
[the instrumented KC705 build](boards/kc705/lab/README.md).

Explicit new commands: `make pipeline-compile`, `make pipeline-test`,
`make test-muldiv`, `make test-injector`, `make formal-pipeline-prepare`,
`make formal-pipeline`, and `make kc705-instrumented`.


## Legacy prototype (0.4)

**RV32IM with ECC, TMR, fault injection, and formal verification.**

Original SystemVerilog RV32IM implementation with radiation-fault mitigation mechanisms, pinned upstream programs, cocotb testing, fault-injection hooks and a triplicated error recorder. **This is a tested prototype, not a radiation-qualified or flight-ready processor.**

## Repository map

| Directory | Contents |
| --- | --- |
| `boards/` | FPGA wrappers, pin constraints and explicit vendor build flows |
| `rtl/` | Core, execution unit, ECC RAM, error recorder and reference SoC |
| `formal/` | RVFI wrapper, riscv-formal configuration and fault/property harnesses |
| `tests/` | SystemVerilog regressions and Python/cocotb campaigns |
| `firmware/` | Bare-metal examples and upstream startup/linker adapters |
| `tools/` | Reproducible fetch, tool setup, build and verification scripts |
| `docs/` | Requirements, architecture, protection inventory and verification scope |
| `verification/evidence/` | Historical completed results and explicitly partial formal evidence |
| `licenses/` | Third-party license notices |
| `third_party/`, `.tools/`, `build/` | Downloaded/generated locally; excluded from Git |

Start with [Architecture](docs/ARCHITECTURE.md), [formal setup](docs/FORMAL.md), and [requirements](docs/REQUIREMENTS.md).

## Quick start

Install Python 3.9+ and the pinned Python packages in a virtual environment:

```sh
python3 -m venv .venv
. .venv/bin/activate
python3 -m pip install -r requirements-test.txt
make test
make cocotb
```

Required executables: GNU Make, git, Icarus Verilog 12+ (`iverilog`, `vvp`), and a bare-metal RISC-V GCC/binutils toolchain supporting `-march=rv32im -mabi=ilp32`. A `riscv64-unknown-elf-` toolchain can target RV32. Set `RISCV_GCC` and `RISCV_OBJCOPY` for a different installation. `make test` runs the standalone SV regressions without the cross compiler; `make cocotb` fetches/builds upstream programs and runs ECC/TMR modes and four interface configurations.

| Target | Purpose |
| --- | --- |
| `make fetch` | Fetch repositories at immutable commits in `upstream.lock.json` |
| `make upstream` | Build 48 instruction test bodies, sieve and Dhrystone |
| `make cocotb-ecc` / `make cocotb-tmr` | Upstream programs and stored-state fault sweeps for one register mode |
| `make interfaces` | FI-disabled/rejection checks, event retention and saturation in both modes |
| `make cocotb` | Both mode campaigns plus interface tests |
| `make test` | Six original SV instruction/ECC/fault/integration tests |
| `make synth-ecc` / `make synth-tmr` | Generic Yosys synthesis plus redundancy audit; requires sv2v/Yosys |

Do not run synthesis targets concurrently: they share `build/rtl.v`, `synthesis.log` and `netlist.json`. The cocotb build/result directories are separate by mode; the supplied Makefile's default sequential execution is recommended. Build generation needs no additional Python libraries beyond the pinned test packages.

## Processor architecture

RV32IM, little-endian, 32 integer registers, x0 hardwired zero, fixed 4-byte instructions, serialized memory requests. Misaligned halfword/word accesses, illegal instructions, ECALL and EBREAK halt and report cause/value/PC through an external execution-environment interface. All eight M operations implement their signed/unsigned, divide-by-zero and overflow cases.

There is no privileged CSR/interrupt/MRET implementation, C/A/F/D extensions, Zifencei, cache, branch predictor or speculative execution. FENCE is an ordering no-op because requests are serialized. Multiply/divide remain combinational operators; no Fmax/area claim is made.

## Register protection options

`RF_TMR=0` (default): 39-bit SECDED per word; reads correct before use, repair writeback and background scrub of x1–x31 every 31 clocks. Uncorrectable data causes fail-stop.

`RF_TMR=1`: three 32-bit replicas, majority-voted operands and repair of all replicas on read/background scrub. This adds 96 stored bits per register instead of 39, approximately 2.46× the RF storage before voter/control costs. One register replica-bit upset is covered; two identical replica errors can silently produce an incorrect majority. They are outside the stated guarantee.

`FI_ENABLE=0` is the production default. `FI_ENABLE=1` enables qualified test-only XOR injection. See FAULT_INJECTION.md for target IDs, timing and coverage. The hook must be tied off/removed in the target implementation.

CPU control, RAM control and error-recorder state are triplicated. CPU FSM encodings have pairwise Hamming distance four, but their correction comes from TMR rather than a Hamming decoder. **All explicit stored-state controllers are protected; shared voters, decode, arithmetic inputs, address selection and commit logic are not comprehensively hardened.** See STATE_MACHINE_AUDIT.md.

## Memory

Every reference SRAM word uses 39/32 SECDED. Address, store-data and control fields have codewords checked at the endpoint. Corrected memory data is repaired. Partial stores perform serialized atomic ECC read/modify/write; detected uncorrectable old data blocks RMW. Full-word stores can overwrite without consuming old data. Background SRAM scrubbing is idle-only and has no worst-case bound under arbitrary continuous standalone traffic.

The request format is `addr_code=ECC(aligned byte address)`, `wdata_code=ECC(lane-aligned store data)`, `ctrl_code=ECC({27'b0,write,byte_mask})`. A request is accepted once, with a synchronous response cycle. Refer to the reference endpoint before replacing it; accepting every asserted request cycle would duplicate transactions.

The FPGA-style initial memory image is not an ASIC power-on guarantee. ASIC/flight integration needs valid ECC initialization and a protected boot sequencer before reset release. Reset clears CPU/register/reporter state but does not erase SRAM.

## Error reporting contract

The new recorder supplies sticky flags, saturating 32-bit observation counters, and first/last PC/address/source masks. It is itself triplicated and reports its own disagreement. Original combinational event outputs remain available. Sample event/retirement outputs at clock edges.

| Sticky bit | Detector/source |
| --- | --- |
| 0 | RF correction or RF TMR repair |
| 1 | RF uncorrectable error |
| 2 | CPU control replica disagreement |
| 3 | CPU memory-response/integrity/access failure |
| 4 | Execution-lane disagreement |
| 5 | Bus timeout |
| 6 | Invalid CPU state/alignment |
| 7 | External subsystem fatal |
| 8 | Memory/request correction |
| 9 | Memory request/read/RMW error, including ECC or access failures |
| 10 | RAM control disagreement |
| 11 | RAM scrub/controller fatal |
| 15 | Recorder replica disagreement |

Counters count **new detector observations**, not radiation particles or unique bad locations. A continuously asserted detector is counted on its rising observation; a recurring scrub detection after a gap can be counted again. Simultaneous sources preserve every source bit but share one metadata slot: RAM address metadata has priority over CPU metadata. RF addresses are register indices; SRAM addresses are byte addresses. First record remains until reset; last record can be overwritten. This is not a lossless FIFO/error log. Corrected-count combines RF and memory corrections; uncorrectable-count also includes memory endpoint access/integrity errors. A supervisor can use the counters/flags and `event_valid` to capture richer telemetry.

Fatal causes: `80000001` invalid state, `80000002` memory failure, `80000003` RF ECC DED, `80000004` execution mismatch, `80000005` timeout, `80000006` external fatal. There is no automatic replay/checkpoint recovery. An already accepted external device transaction cannot be undone by a later halt.

## Upstream testing

The Makefile fetches a locked riscv-tests commit and PicoRV32 commit, rejects dirty/wrong checkouts, and keeps their sources unchanged. A local `riscv_test.h` substitutes startup/pass/fail behavior for our external trap interface; the original self-checking instruction bodies/macros are used. `fence_i` and `ma_data` are explicitly excluded because their expected environment is not implemented. These adapted runs are not ACT4/RISC-V certification.

The sieve validates its upstream checksum. Dhrystone executes its original 100-iteration C workload and validates final global/record values. Its timing functions are stubs: **no Dhrystone score, DMIPS or timing measurement is claimed**. Programs compile for RV32IM/ILP32 without compressed instructions, with startup/linker/output adapters under `firmware/upstream/`.

The archive includes built ELF/bin images, their manifest, source pins and licenses so the exercised binaries can be inspected. Rebuilding needs the fetched source and compiler. The fetched git checkouts are not included in the archive.

## Documentation and evidence

- `docs/REQUIREMENTS.md`, `requirements.json`, `requirements.csv`: 33 strict requirements with verification and open-item status.
- `docs/STATE_MACHINE_AUDIT.md`: state/control inventory and coverage gaps.
- `docs/FAULT_INJECTION.md`: deterministic stored-bit injection contract.
- `docs/PROTECTION.md`: physical/common-mode/qualification limitations.
- `docs/VALIDATION.md` and `verification/evidence/`: executed results, JSON campaigns, JUnit XML and synthesis audits.

No test here validates analog SET pulse widths, physical multi-node strikes, SEL immunity, TID, FPGA configuration upset handling or mission-level residual error rate. Target-specific design, layout and radiation testing remain required.

## Free formal verification

See [docs/FORMAL.md](docs/FORMAL.md) for reproducible setup, proof contracts and limitations. `make formal` downloads SHA256-verified pinned tools, fetches riscv-formal at an immutable commit, and runs ECC, error reporting, RAM faults, core fault comparison, RVFI ISA checks and reachability covers. Requires Linux x86-64 or WSL2 and Python 3.12+.

## Automated workflows

[Formal verification](.github/workflows/formal.yml) is available through **Actions → Formal verification → Run workflow**. It is manual-only while the proof campaigns are being developed. Pushes do not start tests. The default run covers the model regression, ECC, error recorder, M execution unit and RAM; the optional full run adds whole-core fault and ISA campaigns.

Compiler outputs and upstream test binaries are rebuilt with `make upstream`; generated ELF/bin files are not checked into Git. Tool binaries and fetched source repositories are also excluded. Versions and checksums live in the lock files.

## Development

See [CONTRIBUTING.md](CONTRIBUTING.md), [CHANGELOG.md](CHANGELOG.md), and the [roadmap](docs/ROADMAP.md). Original code is MIT licensed; third-party notices are retained in `licenses/` and upstream sources keep their own licenses.

## KC705 FPGA target

See [boards/kc705/README.md](boards/kc705/README.md). `make kc705` prepares firmware and builds the XC7K325T target with Vivado; `RF_MODE=tmr` selects triplicated registers. The wrapper provides LEDs, periodic USB-UART status and optional button fault injection. No target bitstream or timing result is claimed yet.
