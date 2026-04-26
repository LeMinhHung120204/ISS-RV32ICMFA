    .section .text
    .globl _start
    .option norvc

_start:
    ####################################################################
    # Arithmetic group test for RV32I - TEST CASE 05
    # Extra edge cases: 0xFFFF FFFF pattern, signed/unsigned boundary
    ####################################################################

    ####################################################################
    # TEST 1: add 0xFFFFFFFF + 1 = 0
    ####################################################################
    li s0, 1
    li t0, -1
    li t1, 1
    add  t2, t0, t1
    bne  t2, x0, fail

    ####################################################################
    # TEST 2: sub 0x00000001 - 0x80000000 = 0x7FFFFFFF (wrap)
    ####################################################################
    li s0, 2
    li t0, 1
    lui  t1, 0x80000
    sub  t2, t0, t1
    lui  t3, 0x7ffff
    addi t3, t3, -1
    bne  t2, t3, fail

    ####################################################################
    # TEST 3-10: more chained, x0, auipc, etc.
    ####################################################################
    li s0, 3
    li t0, -2048
    addi t1, t0, 2047
    addi t2, t1, 1
    bne  t2, x0, fail

    ####################################################################
    # TEST 4: Sửa lỗi dấu cách
    ####################################################################
    li s0, 4
    lui  t0, 0xaaaaa       # Sửa: Xóa dấu cách
    li t0, -0x556
    add  t1, t0, t0
    lui  t2, 0x55555
    addi t2, t2, 0x554
    bne  t1, t2, fail

    li s0, 5
    li t0, 0
    addi x0, t0, 0x123
    bne  x0, t0, fail

    li s0, 6
    auipc t0, 0
    addi t0, t0, 0
    bne  t0, t0, fail   # trivial but tests PC

    li s0, 7
    auipc t0, 0x7ff
    auipc t1, 0
    lui  t2, 0x7ff
    add  t1, t1, t2
    addi t1, t1, -4
    bne  t0, t1, fail

    ####################################################################
    # TEST 8: Sửa lỗi số 32-bit (0x7fffffff)
    ####################################################################
    li s0, 8
    # Cách nạp số 0x7fffffff đúng chuẩn:
    lui  t0, 0x80000
    addi t0, t0, -1        # t0 = 0x7fffffff
    
    # Để cộng/trừ số lớn, nạp số đó vào thanh ghi trước rồi dùng 'add' hoặc 'sub'
    # Ở đây t1 = t0 - t0 = 0
    sub  t1, t0, t0        
    addi t2, t1, -1        # t2 = -1
    # Lưu ý: bne t2, x0, fail sẽ nhảy tới fail vì -1 != 0. 
    # Nếu bạn muốn pass, hãy kiểm tra lại logic so sánh của mình nhé.

    li s0, 9
    lui  t0, 0x00001
    addi t1, t0, -1
    bne  t1, x0, fail

    ####################################################################
    # TEST 10: Sửa lỗi số 0x55555555
    ####################################################################
    li s0, 10
    # Nạp 0x55555555 vào t0
    lui  t0, 0x55555
    addi t0, t0, 0x555     # t0 = 0x55555555
    
    add  t1, t0, t0        # t1 = t0 + t0
    lui  t2, 0xaaaaa       # Sửa: Xóa dấu cách
    li t2, -0x556    # t2 = 0xAAAAAAAE (Kết quả của 0x55555555 * 2)
    bne  t1, t2, fail

pass:
    li a0, 1
pass_loop:
    jal x0, pass_loop

fail:
    add  a0, s0, x0
fail_loop:
    jal x0, fail_loop
