OUTPUT_ARCH(riscv)
ENTRY(_start)
MEMORY { RAM (rwx) : ORIGIN = 0, LENGTH = 0x7f00 }
SECTIONS {
 .text : { KEEP(*(.text.start)) *(.text*) } > RAM
 .rodata : { *(.rodata*) } > RAM
 .data : { . = ALIGN(16); PROVIDE(__global_pointer$ = . + 0x800); *(.data*) *(.sdata*) } > RAM
 .bss (NOLOAD) : { . = ALIGN(16); _bss_start = .; *(.bss*) *(.sbss*) *(COMMON) . = ALIGN(16); _bss_end = .; } > RAM
 _end = .;
 _stack_top = ORIGIN(RAM) + LENGTH(RAM);
 ASSERT(_end <= _stack_top - 0x1000, "Leave 4 KiB stack and reserved mailbox")
}
