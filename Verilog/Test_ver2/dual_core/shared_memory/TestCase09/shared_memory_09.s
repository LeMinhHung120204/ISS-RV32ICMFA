# Group: shared_memory | TestCase: 09 (TC69)
# Description: Concur_Struct (Concurrent Structure Access)
# Core 0 updates payload then metadata. Core 1 polls metadata then reads payload.
.section.text
.global _start
_start:
    csrr t0, mhartid
    la sp, system_stacks + 1024
    li t1, 1024; mul t1, t0, t1; add sp, sp, t1
    la a1, my_struct
    
    beqz t0, core0_main
    li t1, 1
    beq t0, t1, core1_main
    j park_core

core0_main:
    # my_struct: offset 0 = metadata (valid flag), offset 4 = payload
    li t1, 0xCAFEBEEF
    sw t1, 4(a1)         # Write Payload FIRST
    
    fence w, w           # Memory barrier
    
    li t2, 1
    sw t2, 0(a1)         # Write Meta (Valid) LAST
    j pass_end

core1_main:
    # Wait for metadata valid
1:  lw t2, 0(a1)
    beqz t2, 1b
    
    fence r, r           # Barrier to ensure payload load doesn't bypass meta check
    
    lw t1, 4(a1)         # Read Payload
    li t3, 0xCAFEBEEF
    bne t1, t3, fail
    
pass_end: li a0, 0; ebreak
fail: li a0, 1; ebreak
park_core: wfi; j park_core

.section.data
.align 6
my_struct:
   .word 0              # Metadata (Valid Flag)
   .word 0              # Payload
system_stacks:.skip 2048
