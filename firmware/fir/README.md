# Signed 32-tap FIR example

This freestanding C example computes four overlapping FIR outputs. Samples are
signed 32-bit sensor values; coefficients are signed Q1.15 values held in
32-bit storage. Each product and the accumulator use signed 64-bit arithmetic.
GCC 13.2 emits MUL for the low half and MULH for the high half of each product.

The maximum magnitude is bounded by 32 * 2^31 * 32768 = 2^51, so accumulation
cannot overflow int64. Normalization divides by 32768 with C's defined
truncation toward zero, then explicitly clips to INT32_MIN/INT32_MAX. This
example checks both clipping directions and two unclipped results. Saturation
is part of this example's output contract, not a hidden CPU overflow behavior.

Input generation uses a deterministic volatile xorshift seed plus explicit
INT_MIN/INT_MAX/-1/0/1 edge samples. Python independently computes every raw
64-bit accumulator and normalized/clipped output with arbitrary-precision
integers. Cocotb checks both accumulator halves and every final result.

```sh
make c-fir-build
make c-fir                  # ECC/TMR RTL simulation, 8 KiB RAM
make test-multiplier-exhaustive
make pipeline-multiplier
```

Requires the bare-metal GCC/binutils toolchain, Icarus and configured cocotb
Python environment described in docs/ELF_COMPATIBILITY.md. `make c-tools`
provides an optional pinned Linux x86-64 compiler; put its bin directory on
PATH. All compiler flags come from software-profile.json, and the linked ELF
passes the compatibility audit before simulation.

This standalone startup initializes sp/gp, clears BSS and calls main. It has
no trap handler; any unexpected trap fails this test. Separate full-core
multiply tests cover interrupts with a handler and MRET. The result mailbox
is at 0x1f00; stack top is 0x1e00. Build artifacts are in build/c-fir.

See docs/MULTIPLIER_VERIFICATION.md and verification/multiplier-results.json
for executed scope and results. No fault injection or physical timing claim
is made by these arithmetic tests.
