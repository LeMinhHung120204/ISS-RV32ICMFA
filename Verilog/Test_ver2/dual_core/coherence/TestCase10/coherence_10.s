# Group: coherence | TestCase: 10 (TC50)
# Description: MOESI_Cycle
# Forces a line through the entire MOESI lifecycle: I -> E -> M -> O -> S -> I
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
    # Step 1: Read (I -> E)
    lw t1, 0(a0)
    
    # Step 2: Write (E -> M)
    li t1, 0x1234
    sw t1, 0(a0)
    
    li t2, 1; sw t2, 0(a1)     # C0 Done with M
    
1:  lw t3, 64(a1); beqz t3, 1b # Wait for C1 to Read (forces C0 M->O)
    
    # Step 4: C0 is in Owned. Read again to maintain O.
    lw t1, 0(a0)
    
    li t2, 2; sw t2, 0(a1)     # C0 Done with O
    
2:  lw t3, 64(a1)
    li t4, 2
    bne t3, t4, 2b             # Wait for C1 to Write (forces C0 O->I)
    
    # Step 6: C0 is now Invalid. Fetching should see C1's new data.
    lw t1, 0(a0)
    li t2, 0x5678
    bne t1, t2, fail
    j pass_end

core1_main:
1:  lw t2, 0(a1); beqz t2, 1b  # Wait for C0 M
    
    # Step 3: Read (C0 M->O, C1 I->S)
    lw t1, 0(a0)
    li t2, 0x1234
    bne t1, t2, fail
    
    li t2, 1; sw t2, 64(a1)    # C1 Done with S
    
2:  lw t2, 0(a1)
    li t3, 2
    bne t2, t3, 2b             # Wait for C0 O
    
    # Step 5: Write (C1 S->M, C0 O->I)
    li t1, 0x5678
    sw t1, 0(a0)
    
    li t2, 2; sw t2, 64(a1)    # C1 Done with M
    j pass_end

pass_end: li a0, 0; ebreak
fail: li a0, 1; ebreak
park_core: wfi; j park_core

.section.data
.align 6
target_var:.word 0x0
.align 6
sync_flags:.word 0x0
.align 6
sync_flag_c1:.word 0x0
system_stacks:.skip 2048
