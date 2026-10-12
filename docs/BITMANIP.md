# RV32 bit manipulation (RISCue 0.7)

The five-stage pipeline implements ratified Zbb 1.0, Zbc 1.0 and Zbs 1.0.
The legacy serialized RV32IM target is unchanged. Both preserved, compared
`riscue_execute` instances independently compute these instructions in EX.
There is no added multicycle state, CSR, fault target or custom opcode.
Normal forwarding, load-use stalls, precise retirement and x0 handling apply.
FI ABI 2 and the protected state widths remain unchanged.

| Extension | Implemented instructions |
| --- | --- |
| Zbb | andn, orn, xnor, clz, ctz, cpop, min, minu, max, maxu, sext.b, sext.h, zext.h, rol, ror, rori, orc.b, rev8 |
| Zbc | clmul, clmulh, clmulr |
| Zbs | bclr, bclri, bext, bexti, binv, binvi, bset, bseti |

CLZ/CTZ of zero return 32. Register bit and rotate indices use the low five
bits; a zero rotate preserves the operand. Immediate encodings require RV32
shamt[5]=0. ZEXT.H requires rs2=0, and REV8 uses the RV32 encoding (0x698).
Reserved encodings trap with mcause=2 and mtval equal to the instruction.
CLMUL is polynomial multiplication over GF(2), without integer carries.
CLMUL, CLMULH and CLMULR select product bits 31:0, 63:32 and 62:31 respectively.
CRC polynomial, reflection and initial/final XOR remain software choices.

Use `-march=rv32imc_zicsr_zifencei_zicntr_zbb_zbc_zbs -mabi=ilp32`.
No custom compiler backend is needed. A toolchain must recognize these named
extensions and provide suitable ILP32 support; a small compiled C workload now passes ECC/TMR simulation. Full compiler/
library and platform firmware execution validation remains pending. `misa` remains 0x40001104: the B aggregate requires Zba as well as
Zbb/Zbs, and Zba is absent. The software profile advertises the named extensions.

## Verification

- `make test-bitmanip`: 5,002 deterministic Python-reference vectors, including
  all 29 instructions, boundary/random operands, every immediate index and ten
  reserved/unsupported encodings. The reference carryless multiplier uses
  bit-pair polynomial convolution, independent of the RTL shifted-word method.
- `make pipeline-bitmanip`: cocotb in both ECC and TMR register modes. Each
  instruction runs eight operand pairs with load-use dependencies, forwarded
  result consumers, store/load round trips and x0 suppression. Reserved
  encodings exercise trap metadata and MRET continuation.
- `make formal-bitmanip`: 29 depth-one combinational proof jobs with arbitrary
  operand values and arbitrary immediate indices. This harness is configured
  and conversion checked; no solver proof result is claimed for this release.
  Existing riscv-formal pipeline jobs retain their RV32IMC baseline scope;
  they do not establish extended-ISA full-core compliance.

See `verification/bitmanip-results.json` for executed results and source hashes.
The implementation is combinational, including a duplicated 32-by-32 carryless
multiplier. FPGA area, routing and EX critical-path timing must be measured in
Vivado; simulation establishes neither a clock-frequency guarantee nor
radiation qualification. An iterative implementation would require protected
state and a revised fault-injection map.

Encoding sources checked against the official riscv-opcodes files:
`extensions/rv_zbb` (blob 0d56c6481d39bf3d6689222345db33aa938bb0e8),
`rv32_zbb` (5a6be10724cc9b04a46e49f36973e027e68b2b2c),
`rv_zbc` (821518bd00e7d4e7154e8538adaa9ef6b7f06a42),
`rv_zbs` (3dd77eb71ea0db51e5d75f8dca0af9b6c58d50d9), and
`rv32_zbs` (fe3c8a26a6151aef44b3760864051dbf5b74c552).

Primary specification: https://docs.riscv.org/reference/isa/unpriv/b-st-ext.html
Official encodings: https://github.com/riscv/riscv-opcodes/tree/master/extensions
