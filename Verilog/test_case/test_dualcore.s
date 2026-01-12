/* start.S */
.section .text
.global _start

_start:
    # 1. Đọc Hardware ID (mhartid)
    csrr a0, mhartid

    # 2. Phân luồng dựa vào ID
    bnez a0, core1_entry  # Nếu a0 != 0 (tức là Core 1), nhảy sang setup cho Core 1

    # --- SETUP CHO CORE 0 ---
core0_entry:
    # Thiết lập Stack Pointer (SP) cho Core 0 tại đỉnh RAM (ví dụ 16KB)
    li sp, 0x4000         
    call main_core0       # Nhảy vào hàm C của Core 0
    j hang                # Nếu main trả về, treo luôn

    # --- SETUP CHO CORE 1 ---
core1_entry:
    # Thiết lập Stack Pointer (SP) cho Core 1 thấp hơn Core 0 một chút (để ko đụng nhau)
    li sp, 0x3000         # Stack Core 1 cách Core 0 4KB
    call main_core1       # Nhảy vào hàm C của Core 1
    j hang

hang:
    j hang                # Vòng lặp vô tận