# Current RISCue architecture

The current CPU is `riscue_pipeline_core`: a five-stage RV32IMC_Zicsr_Zifencei_Zicntr_Zbb_Zbc_Zbs M-mode implementation. The complete architecture walkthrough and code excerpts are in [the manual](RISCUE_MANUAL.md#five-stage-pipeline).

IF fetches and decompresses instructions, including word-straddling 32-bit instructions. ID reads protected registers and can redirect direct jumps early. EX contains compared integer and multicycle arithmetic lanes. MEM accesses RAM or internal CLINT registers. WB commits GPR/CSR state and precise traps. A unified, held-request memory interface limits throughput; stage overlap does not imply one instruction per clock.

Pipeline/platform state is triplicated. Registers use SECDED or TMR. Local SRAM uses 39/32 SECDED and a triplicated controller. The generic `riscue_axi_core` converts the CPU's ECC-coded requests into single-outstanding AXI4-Lite traffic. The AXI RAM endpoint regenerates/checks storage ECC; AXI transport itself is not ECC protected.

The default KC705 system adds an independent UART command monitor with its own AXI master. The CPU and monitor use exclusive RAM ownership, changing only after transaction drain. The CPU starts held in reset; an ELF loader can load, verify, start, stop and inspect programs. The monitor's control path is unprotected laboratory infrastructure.

The local-memory `riscue_pipeline_soc` remains the fixture for many pipeline tests and the original VIO/ILA board target. KV260 provides a separate ARM host-control slave and local memory path. The preserved `rv32im_ft_*` modules are an older serialized CPU; see [historical architecture](LEGACY_ARCHITECTURE.md).

References: [pipeline detail](PIPELINE_IMPLEMENTATION.md), [AXI master](AXI_PROCESSOR.md), [ECC slave](AXI_ECC_MEMORY.md), [monitor](KC705_MONITOR.md), [state inventory](STATE_MACHINE_AUDIT.md), [validation](VALIDATION.md).
