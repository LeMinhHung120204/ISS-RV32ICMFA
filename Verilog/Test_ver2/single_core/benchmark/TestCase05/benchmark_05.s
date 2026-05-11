# Group: benchmark | TestCase: 05
# Description: Bubble Sort & Reverse Sorted Array Stress
# Tests nested conditional branches and intensive in-place memory swaps.
.section.text
.global _start
_start:
    csrr t0, mhartid
    bnez t0, park_core

    la a0, array         
    li a1, 5             # Array size

outer_loop:
    li t0, 0             # swapped = false
    li t1, 1             # i = 1
inner_loop:
    bge t1, a1, end_inner
    
    slli t2, t1, 2       
    add t3, a0, t2
    lw t4, -4(t3)        # arr[i-1]
    lw t5, 0(t3)         # arr[i]

    ble t4, t5, no_swap
    
    # Swap
    sw t5, -4(t3)
    sw t4, 0(t3)
    li t0, 1             # swapped = true

no_swap:
    addi t1, t1, 1
    j inner_loop

end_inner:
    bnez t0, outer_loop  

check:
    # Array should be sorted: 11, 22, 45, 88, 99
    lw t1, 0(a0)         
    li t2, 11
    bne t1, t2, fail
    
    lw t1, 16(a0)        # Last element
    li t2, 99
    bne t1, t2, fail
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
# Corner Case: Reverse sorted array forces maximum number of swaps
array:.word 99, 88, 45, 22, 11
