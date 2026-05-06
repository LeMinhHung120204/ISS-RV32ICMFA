# Group: benchmark | TestCase: 03
# Description: Fibonacci (Iterative) & N=0 Corner Case
# Tests tight arithmetic loops and data dependency chains.
.section.text
.global _start
_start:
    csrr t0, mhartid
    bnez t0, park_core

    # Corner Case: Fib(0)
    li a0, 0
    li t0, 0             
    li t1, 1             
    beqz a0, check_fib0

    # Normal Case: Fib(10)
    li a0, 10
fib_loop:
    add t2, t0, t1       
    add t0, t1, zero            
    add t1, t2, zero            
    addi a0, a0, -1
    bnez a0, fib_loop
    j check_fib10

check_fib0:
    bnez t0, fail
    # Proceed to Fib(10)
    li a0, 10
    j fib_loop

check_fib10:
    # Fib(10) iteratively results in Fib(10) in t0 = 55
    li t3, 55
    bne t0, t3, fail

pass:
    li a0, 0
    ebreak
fail:
    li a0, 1
    ebreak
park_core:
    wfi
    j park_core
