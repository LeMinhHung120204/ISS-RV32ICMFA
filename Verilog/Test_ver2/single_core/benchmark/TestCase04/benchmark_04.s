# Group: benchmark | TestCase: 04
# Description: Factorial (Recursive) with Software Multiply
# Tests stack integrity (sp), ra saving/restoring, and JAL/JALR without M-extension.
.section.text
.global _start
_start:
    csrr t0, mhartid
    bnez t0, park_core

    la sp, stack_end     
    li a0, 5             # Calculate 5!
    jal ra, factorial
    
check:
    li t1, 120           # 5! = 120
    bne a0, t1, fail
pass:
    li a0, 0
    ebreak
fail:
    li a0, 1
    ebreak

# Recursive Factorial
factorial:
    addi sp, sp, -16
    sw ra, 12(sp)
    sw a0, 8(sp)

    li t0, 1
    bgt a0, t0, rec_case
    
    # Base case
    li a0, 1
    addi sp, sp, 16
    ret

rec_case:
    addi a0, a0, -1
    jal ra, factorial    # Recursive call returns in a0
    
    lw t1, 8(sp)         # Load original n
    # Software Multiply: a0 = a0 * t1
    add t2, zero, zero
    add t3, a0, zero
mul_loop:
    beqz t1, mul_done
    add t2, t2, t3
    addi t1, t1, -1
    j mul_loop
mul_done:
    add a0, t2, zero     # Move result to a0
    
    lw ra, 12(sp)
    addi sp, sp, 16
    ret

park_core:
    wfi
    j park_core

.section.data
.align 4
stack_space:.space 1024
stack_end:
