ENTRY(_start)
SECTIONS {
 . = 0;
 .text : { *(.text.start) *(.text*) }
 .rodata : { *(.rodata*) }
 . = ALIGN(16);
 .data : { *(.data*) *(.sdata*) }
 .bss : { *(.bss*) *(.sbss*) *(COMMON) }
 _end = .;
 ASSERT(_end < 0x7000, "firmware must leave stack space")
}
