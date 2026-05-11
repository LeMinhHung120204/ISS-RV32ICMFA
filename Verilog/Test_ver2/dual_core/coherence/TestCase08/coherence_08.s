# Group: coherence | TestCase: 08 (TC48)
# Description: WB_Modified (Eviction)
# Core 0 holds Modified. It then thrashes its own cache to force Evict to RAM.
.section.text
.global _start
_start:
    csrr t0, mhartid
    la sp, system_stacks + 1024
    mul t1, t0, 1024
    add sp, sp, t1
    la a0, target_var
    la a1, sync_flags
    la a2, thrash_array
    
    beqz t0, core0_main
    li t1, 1
    beq t0, t1, core1_main
    j park_core

core0_main:
    # 1. Modify Target (M state)
    li t1, 0x88888888
    sw t1, 0(a0)
    
    # 2. Thrash Cache to force Eviction of target_var down to memory
    li t2, 8192       # Loop 8192 times (32KB write to guarantee flush)
1:  sw t2, 0(a2)
    addi a2, a2, 4
    addi t2, t2, -1
    bnez t2, 1b
    
    # Signal Core 1
    li t4, 1; sw t4, 0(a1)
    j pass_end

core1_main:
1:  lw t2, 0(a1); beqz t2, 1b

    # Read from Memory (since Core 0 evicted it)
    lw t1, 0(a0)
    li t2, 0x88888888
    bne t1, t2, fail

pass_end: li a0, 0; ebreak
fail: li a0, 1; ebreak
park_core: wfi; j park_core

.section.data
.align 6
target_var:.word 0x0
.align 6
sync_flags:.word 0x0
.align 6
thrash_array:.space 32768
system_stacks:.skip 2048
