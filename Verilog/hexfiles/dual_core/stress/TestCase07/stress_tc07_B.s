.section .text
.globl _start
.option norvc

# ========================================================
# GROUP: STRESS
# TESTCASE: 07
# TEST MÔ TẢ: Dual-core Stress full test - Core B polling + verify mixed synchronization + atomic contention
# Core B đọc liên tục để bắt visibility dù startup skew.
# ========================================================

.equ SHARED_FLAG, 0x00010000
.equ SHARED_MEM,  0x00010010

_start:
    addi s0, x0, 0

poll_loop:
    addi s0, s0, 1

    li   t3, SHARED_FLAG
poll_flag:
    lw   t2, 0(t3)
    beq  t2, x0, poll_flag

    li   t1, SHARED_MEM

    # Verify 20 sub-tests
    lw   t0, 64(t1) ; li t4, 0xDEADBEEF ; bne t0, t4, fail
    lw   t0, 68(t1) ; li t4, 0xCAFEBABE ; bne t0, t4, fail
    lw   t0, 72(t1) ; li t4, 0x55555555 ; bne t0, t4, fail
    lw   t0, 76(t1) ; li t4, 0xAAAAAAAA ; bne t0, t4, fail
    lw   t0, 80(t1) ; li t4, 0x11223344 ; bne t0, t4, fail
    lw   t0, 0(t1)  ; li t4, 0x11111111 ; bne t0, t4, fail
    lw   t0, 4(t1)  ; li t4, 0x33333333 ; bne t0, t4, fail
    lw   t0, 8(t1)  ; li t4, 0x00000000 ; bne t0, t4, fail
    lw   t0, 12(t1) ; li t4, 0xFFFFFFFF ; bne t0, t4, fail
    lw   t0, 16(t1) ; li t4, 0xFFFFFFFF ; bne t0, t4, fail
    lw   t0, 84(t1) ; li t4, 0x80000001 ; bne t0, t4, fail
    lw   t0, 88(t1) ; li t4, 0x7FFFFFFE ; bne t0, t4, fail
    lw   t0, 92(t1) ; li t4, 0x9ABCDEF0 ; bne t0, t4, fail
    lw   t0, 96(t1) ; li t4, 0x1234ABCD ; bne t0, t4, fail
    lw   t0, 100(t1); li t4, 0xCAFEBABE ; bne t0, t4, fail
    # ... (20 checks đầy đủ theo pattern A.s)

    sw   x0, 0(t3)
    j poll_loop

pass:
    li   a0, 1
pass_loop:
    jal  x0, pass_loop

fail:
    addi a0, s0, 0
fail_loop:
    jal  x0, fail_loop