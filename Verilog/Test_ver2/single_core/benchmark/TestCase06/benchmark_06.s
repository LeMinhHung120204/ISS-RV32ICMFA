# Group: benchmark | TestCase: 06
# Description: Binary Search & Not-Found Boundary Condition
# Tests division by shifting, loop invariants, and array probing.
.section.text
.global _start
_start:
    csrr t0, mhartid
    bnez t0, park_core

    la a0, sorted_arr    
    li a1, 0             # Left
    li a2, 6             # Right
    li a3, 44            # Target

search_loop:
    bgt a1, a2, not_found
    add t0, a1, a2
    srli t0, t0, 1       # Mid = (Left + Right) >> 1
    
    slli t1, t0, 2
    add t1, a0, t1
    lw t2, 0(t1)         # arr[Mid]
    
    beq t2, a3, found
    blt t2, a3, go_right

go_left:
    addi a2, t0, -1
    j search_loop
    
go_right:
    addi a1, t0, 1
    j search_loop

found:
    li t3, 4             # Index of 44 is 4
    bne t0, t3, fail
    j test_not_found

not_found:
    # Target 999 should end here
    li t3, 999
    bne a3, t3, fail
    j pass

test_not_found:
    li a1, 0
    li a2, 6
    li a3, 999           # Corner case: Not in array
    j search_loop

pass:
    li a0, 0
    ebreak
fail:
    li a0, 1
    ebreak
park_core:
    wfi
    j park_core

.section.data
.align 4
sorted_arr:.word 2, 5, 12, 33, 44, 55, 99
