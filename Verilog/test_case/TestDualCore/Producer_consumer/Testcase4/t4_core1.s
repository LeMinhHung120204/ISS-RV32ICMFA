.section .text.init
    .globl _start
_start:
    j main

    .text
main:
    # --- 1. Khởi tạo địa chỉ Shared Memory ---
    addi  x10, x0, 0x200     # x10 = 0x200 (Base Address - Data Buffer)
    addi  x17, x10, 0x40     # x17 = 0x240 (Địa chỉ của Empty)
    addi  x18, x10, 0x80     # x18 = 0x280 (Địa chỉ của Full)

    # Khởi tạo Semaphore ban đầu (Chỉ Core 0/1 làm việc này)
    addi  x15, x0, 1
    sw    x15, 0(x17)        # Empty = 1 (Đang trống)
    sw    x0,  0(x18)        # Full  = 0 (Chưa có gì)

    # --- 2. Khởi tạo biến đếm ---
    addi  x11, x0, 0         # x11 = 0 (Biến đếm)
    addi  x12, x0, 10        # x12 = 10 (Giới hạn lặp)
    addi  x16, x0, 1         # Thanh ghi hằng số 1 

producer_loop:
    beq   x11, x12, end_test # Đủ 10 vòng thì kết thúc

wait_empty:
    # Lệnh amoadd.w: Đọc nguyên tử cờ Empty (M = M + 0).
    amoadd.w  x14, x0, (x17) 
    beq       x14, x0, wait_empty   

    # Lệnh amoxor.w: Lật bit cờ Empty từ 1 về 0 (M = M ^ 1).
    amoxor.w  x0, x16, (x17)   

    # --- CRITICAL SECTION: SẢN XUẤT ---
    addi      x13, x11, 100
    sw        x13, 0(x10)

    # Lệnh amoxor.w: Lật bit cờ Full từ 0 lên 1.
    amoxor.w  x0, x16, (x18)   

    addi      x11, x11, 1        
    j         producer_loop

end_test:
    addi  x26, x0, 1         # x26 = 1 (Báo Done)
spin:
    j     spin