.section .text
.globl _start
.option norvc

# ========================================================
# GROUP: BASIC
# TESTCASE: 01
# TEST MÔ TẢ: Basic shared memory visibility - Core B polling flag + verify data
# Core A đã ghi, Core B kiểm tra giá trị có đúng không
# Trường hợp đặc biệt: polling liên tục (handle startup skew), check 10 magic values
# ========================================================

.equ SHARED_FLAG, 0x00010000
.equ SHARED_DATA, 0x00010004

_start:
    addi s0, x0, 0                  # s0 = sub-test ID

poll_loop:
    addi s0, s0, 1

    li   t3, SHARED_FLAG
poll_flag:
    lw   t2, 0(t3)
    beq  t2, x0, poll_flag          # chờ flag != 0

    li   t1, SHARED_DATA
    lw   t0, 0(t1)                  # đọc data

    # Kiểm tra giá trị theo sub-test (magic values giống Core A)
    li   t4, 0xDEADBEEF
    beq  s0, 1, check1
    li   t4, 0xCAFEBABE
    beq  s0, 2, check2
    li   t4, 0x12345678
    beq  s0, 3, check3
    li   t4, 0x55555555
    beq  s0, 4, check4
    li   t4, 0xAAAAAAAA
    beq  s0, 5, check5
    li   t4, 0xFFFFFFFF
    beq  s0, 6, check6
    li   t4, 0x00000000
    beq  s0, 7, check7
    li   t4, 0x80000000
    beq  s0, 8, check8
    li   t4, 0x7FFFFFFF
    beq  s0, 9, check9
    li   t4, 0x1234ABCD
    beq  s0, 10, check10

check1:
check2:
check3:
check4:
check5:
check6:
check7:
check8:
check9:
check10:
    bne  t0, t4, fail               # sai → fail
    sw   x0, 0(t3)                  # clear flag cho sub-test tiếp theo

    j poll_loop                     # tiếp tục sub-test sau

pass:
    li   a0, 1
pass_loop:
    jal  x0, pass_loop

fail:
    addi a0, s0, 0                  # a0 = failing sub-test ID
fail_loop:
    jal  x0, fail_loop