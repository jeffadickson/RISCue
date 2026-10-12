# Software profile and linked-ELF compatibility

`docs/software-profile.json` is the source for pipeline compiler flags.
`tools/software_profile.py` validates ISA/ABI consistency and emits
`build/software-profile.mk`. The firmware Make target includes that generated
file; the pipeline upstream and C smoke builders load the same JSON directly.
The legacy upstream target retains its separate RV32IM contract.

Commands:

```sh
make software-profile
make test-software-profile
make test-elf-toolchain   # Actual GCC/binutils negative fixtures
make firmware-platform
make check-elf ELF=path/to/linked.elf
make c-smoke             # Installed RISC-V GCC/binutils and cocotb required
make c-smoke-local       # Explicit checksum-pinned local compiler setup
```

`c-tools` extracts Ubuntu Noble GCC 13.2 and binutils 2.42 into `.tools/riscv` on
Linux x86-64. Package SHA256 values were verified against the official Ubuntu
package download pages; future downloads must match these pinned hashes.
It does not install system packages. For other hosts use a suitable native
bare-metal toolchain. Set RISCV_GCC, RISCV_OBJCOPY, RISCV_READELF, RISCV_OBJDUMP
and RISCV_NM to select tools. Simulation also requires `make pipeline-tools`
and an Icarus installation on PATH.

The post-link checker invokes GNU `readelf -A` and
`objdump -d -z -M no-aliases,numeric`. It requires ELF32 little-endian RISC-V
ET_EXEC, integer ABI flags, supported versioned architecture attributes, and
supported mnemonics throughout GNU-decoded executable sections. M's implied
Zmmul and C's implied Zca are accepted. It rejects missing architecture
attributes, unsupported extensions/versions, RV64/float/atomic/vector/custom
instructions, undecoded words and inconsistent widths. The exact ZEXT.H
encoding can be printed as PACK by a no-alias disassembler; only rs2=0 is
accepted as Zbb. New binutils mnemonics fail closed until reviewed.

This is a conservative build audit, not a machine-code verifier or reachability
proof. It relies on binutils decoding and the ELF section/symbol metadata.
Embedded data or illegal-instruction sentinels in executable sections can be
rejected even if unreachable; separate data and use legal NOP alignment.
It does not analyze indirect jumps, computed code, runtime overlays, CSR
addresses/permissions, MMIO semantics or self-modification. Missing/disguised
code and mutable code require additional policy and runtime protections.
Platform loader RAM/entry checks and core traps remain separate mechanisms.
An accepted file is not evidence of complete hardware ISA compliance.

The firmware and pipeline upstream builders audit the linked image before
objcopy, catching linked-library and assembly additions as well as C output.
The ELF audit does not run the program. Actual C simulation evidence is in
`verification/c-smoke-results.json`; all tests have their declared scope.
