ENTRY(_start)
SECTIONS {
 . = 0;
 .text : { *(.text.start) *(.text*) }
 .rodata : { *(.rodata*) }
 .data : { *(.data*) *(.sdata*) }
 .bss : { *(.bss*) *(.sbss*) *(COMMON) }
 /DISCARD/ : { *(.eh_frame*) *(.comment*) }
}
