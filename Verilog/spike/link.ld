OUTPUT_ARCH(riscv)
ENTRY(_start)

MEMORY
{
  RAM (rwx) : ORIGIN = 0x80000000, LENGTH = 256K
}

SECTIONS
{
  .text : { *(.text.init) *(.text*) } > RAM
  .rodata : { *(.rodata*) } > RAM
  .data : { *(.data*) } > RAM
  .bss : { *(.bss*) *(COMMON) } > RAM
}
