# Group: coherence | TestCase: 07 (TC47)
# Description: C2C_Transfer (Cache to Cache)
# Validates data integrity of direct cache-to-cache transfers bypassing memory.
.section.text
.global _start
_start:
    csrr t0, mhartid
    la sp, system_stacks + 1024
    mul t1, t0, 1024
    add sp, sp, t1
    la a0, target_var
    la a1, sync_flags
    
    beqz t0, core0_main
    li t1, 1
    beq t0, t1, core1_main
    j park_core

core0_main:
    li t1, 0xAAAA
    li t2, 0xBBBB
    li t3, 0xCCCC
    sw t1, 0(a0)
    sw t2, 4(a0)
    sw t3, 8(a0)
    
    li t4, 1; sw t4, 0(a1)
1:  lw t5, 64(a1); beqz t5, 1b
    j pass_end

core1_main:
1:  lw t2, 0(a1); beqz t2, 1b

    # Reads must hit in Core 0's cache (M->O transfer)
    lw t1, 0(a0)
    li t4, 0xAAAA
    bne t1, t4, fail
    
    lw t2, 4(a0)
    li t4, 0xBBBB
    bne t2, t4, fail
    
    lw t3, 8(a0)
    li t4, 0xCCCC
    bne t3, t4, fail

    li t4, 1; sw t4, 64(a1)

pass_end: li a0, 0; ebreak
fail: li a0, 1; ebreak
park_core: wfi; j park_core

.section.data
.align 6
target_var:.space 64
.align 6
sync_flags:.word 0x0
.align 6
sync_flag_c1:.word 0x0
system_stacks:.skip 2048
