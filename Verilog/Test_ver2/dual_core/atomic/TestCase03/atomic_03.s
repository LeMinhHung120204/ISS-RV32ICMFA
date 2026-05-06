# Group: atomic | TestCase: 03 (TC33)
# Description: AMOAND.W / AMOOR.W Bitwise Contention
.section.text
.global _start
_start:
    csrr t0, mhartid
    la sp, system_stacks + 1024
    li t1, 1024
    mul t1, t0, t1
    add sp, sp, t1
    la a0, shared_bits
    la a1, sync_flags
    
    beqz t0, core0_main
    li t1, 1
    beq t0, t1, core1_main
    j park_core

core0_main:
    li t1, 1
    sw t1, 0(a1)
1:  lw t2, 4(a1)
    beqz t2, 1b

    li t1, 0xFFFF0000
    amoor.w zero, t1, (a0)
    
    li t1, 2; sw t1, 0(a1)
    1: lw t2, 4(a1); li t3, 2; bne t2, t3, 1b
    j check_result

core1_main:
    li t1, 1
    sw t1, 4(a1)
1:  lw t2, 0(a1)
    beqz t2, 1b

    li t1, 0x0000FFFF
    amoand.w zero, t1, (a0)
    
    li t1, 2; sw t1, 4(a1)
    1: lw t2, 0(a1); li t3, 2; bne t2, t3, 1b
    j pass_end

check_result:
    # Original is 0. 
    # If OR happens first, value is 0xFFFF0000. Then AND with 0x0000FFFF -> 0x00000000
    # If AND happens first, value is 0. Then OR with 0xFFFF0000 -> 0xFFFF0000
    lw t1, 0(a0)
    beqz t1, pass_end
    li t2, 0xFFFF0000
    beq t1, t2, pass_end
    j fail

pass_end: li a0, 0; ebreak
fail: li a0, 1; ebreak
park_core: wfi; j park_core

.section.data
.align 4
shared_bits:  .word 0x00000000
sync_flags:   .word 0x0, 0x0
system_stacks:.skip 2048
