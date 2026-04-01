.section .text.init
.globl _start
_start:
    # Đọc mhartid để phân biệt 2 core
    csrr    a0, mhartid
    bnez    a0, hart1_loop      # Core 1 (hart ≠ 0) nhảy vào loop an toàn

    # === Core 0 (hart 0) chạy main() ===
    call    main

    # === Báo Spike kết thúc test (để tự động dừng) ===
    li      a0, 1
    li      t0, 0x80001000
    sw      a0, 0(t0)

    # Dừng vô hạn an toàn
1:  j       1b

hart1_loop:
    # Core 1 chỉ loop vô hạn (không crash)
1:  j       1b
