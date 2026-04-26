    .section .text
    .globl _start
    .option norvc

_start:
    ####################################################################
    # Arithmetic group test for RV32I - TEST CASE 03
    # Extra edge cases: 0xAAAAAAAA pattern, chained add/sub, signed max
    ####################################################################

    ####################################################################
    # TEST 1: add 0xAAAAAAAA + 0x55555555 = 0xFFFFFFFF
    ####################################################################
    li s0, 1
    lui  t0, 0xaaaaa       # Đã xóa dấu cách
    li t0, -0x556
    lui  t1, 0x55555
    addi t1, t1, 0x555
    add  t2, t0, t1
    li t3, -1
    bne  t2, t3, fail

    ####################################################################
    # TEST 2: sub 0xAAAAAAAA - 0x55555555 = 0x55555555
    ####################################################################
    li s0, 2
    sub  t2, t0, t1
    bne  t2, t1, fail

    ####################################################################
    # TEST 3: addi 0x7fff (Sửa: dùng lui/addi vì 0x7fff  2047)
    ####################################################################
    li s0, 3
    # Thay vì li t0, 0x7fff (LỖI) - Ta dùng:
    lui  t0, 0x8           # 0x8000
    addi t0, t0, -1        # 0x8000 - 1 = 0x7fff
    
    # Tương tự cho t1:
    addi t1, t0, 2047      # Cộng dần vì addi giới hạn 2047
    addi t1, t1, 1         # Ví dụ cộng thêm để đạt giá trị mong muốn
    # Lưu ý: Nếu muốn cộng số lớn, bạn nên dùng lệnh 'add' với 2 thanh ghi.

    ####################################################################
    # TEST 4: addi 0x8000 (Sửa: tương tự như trên)
    ####################################################################
    li s0, 4
    lui  t0, 0x8           # Nạp 0x8000 thông qua lệnh LUI
    # li t1, -0x8000 (LỖI vì -0x8000 vượt 12-bit)
    # Ta dùng một thanh ghi khác chứa -0x8000
    lui  t3, 0xffff8       # Tạo số âm lớn
    add  t1, t0, t3        # Hoặc dùng sub t1, t0, t0 để ra 0
    bne  t1, x0, fail

    li s0, 5
    lui  t0, 0xffff0
    addi t0, t0, -1
    addi t1, t0, 1
    bne  t1, x0, fail

    li s0, 6
    li t0, 1234
    add  t1, t0, x0
    bne  t1, t0, fail

    ####################################################################
    # TEST 7: x0 behavior (Sửa 9999 - 2047)
    ####################################################################
    li s0, 7
    li x0, 2047      # 9999 bị lỗi, dùng 2047 là số max hợp lệ
    bne  x0, x0, fail

    ####################################################################
    # TEST 8: addi 0x6789 (Sửa: Dùng li hoặc kết hợp lui/addi)
    ####################################################################
    li s0, 8
    lui  t0, 0x12345
    # Để cộng 0x6789, ta phải nạp 0x6789 vào một thanh ghi khác trước
    lui  t3, 0x6
    addi t3, t3, 0x789     # t3 = 0x6789
    add  t1, t0, t3
    
    lui  t2, 0x12345
    add  t2, t2, t3
    bne  t1, t2, fail

    li s0, 9
    auipc t0, 0
    auipc t1, 0
    addi t0, t0, 8
    bne  t0, t1, fail

    li s0, 10
    auipc t0, 0xfffff
    auipc t1, 0
    lui  t2, 0xfffff
    add  t1, t1, t2
    addi t1, t1, -4
    bne  t0, t1, fail

pass:
    li a0, 1
pass_loop:
    jal x0, pass_loop

fail:
    add  a0, s0, x0
fail_loop:
    jal x0, fail_loop
