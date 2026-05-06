# Group: benchmark | TestCase: 02
# Description: String Length & Empty String Corner Case
# Tests arithmetic counters, zero-checking, and branch prediction on empty arrays.
.section.text
.global _start
_start:
    csrr t0, mhartid
    bnez t0, park_core

    # Test 1: Normal string
    la a0, my_str
    li t0, 0             
len_loop:
    add t1, a0, t0       
    lb t2, 0(t1)
    beqz t2, test2       
    addi t0, t0, 1       
    j len_loop

test2:
    li t3, 11            # "Hello World" is 11 chars
    bne t0, t3, fail

    # Test 2: Corner Case - Empty string (immediate NULL)
    la a0, empty_str
    li t0, 0
empty_loop:
    add t1, a0, t0
    lb t2, 0(t1)
    beqz t2, check_empty
    addi t0, t0, 1
    j empty_loop

check_empty:
    bnez t0, fail        # Length must be 0

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
my_str:.asciz "Hello World"
empty_str:.asciz ""
