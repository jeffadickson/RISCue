OUTPUT_ARCH(riscv)
ENTRY(_start)
MEMORY { RAM (rwx) : ORIGIN = 0, LENGTH = 0xf00 }
SECTIONS {
 .text : { KEEP(*(.text.start)) *(.text*) } > RAM
 .rodata : { *(.rodata*) } > RAM
 .data : { . = ALIGN(16); PROVIDE(__global_pointer$ = . + 0x800); *(.data*) *(.sdata*) } > RAM
 .bss (NOLOAD) : { . = ALIGN(16); _bss_start = .; *(.bss*) *(.sbss*) *(COMMON) . = ALIGN(16); _bss_end = .; } > RAM
 mailbox = 0xfc0;
 _stack_top = ORIGIN(RAM) + LENGTH(RAM);
 ASSERT(_bss_end <= _stack_top - 0x400, "Reserve 1 KiB stack")
}
