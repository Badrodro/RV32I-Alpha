OUTPUT_ARCH(riscv)
ENTRY(_start)
SECTIONS
{
  . = 0x0;
  .text : { *(.text.init) *(.text*) }
  . = ALIGN(0x1000);
  .data : { *(.data*) *(.sdata*) *(.bss*) *(.sbss*) }
}
