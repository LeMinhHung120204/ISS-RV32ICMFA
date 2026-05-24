.section .text.init
    .globl _start
_start:
    j main

    .text
main:
    # --- 1. Khởi tạo địa chỉ Shared Memory ---
    addi  x10, x0, 0x200     # x10 = 0x200 (Base Address)
    addi  x17, x10, 0x40     # x17 = 0x240 (Địa chỉ của Empty)
    addi  x18, x10, 0x80     # x18 = 0x280 (Địa chỉ của Full)

    # --- 2. Khởi tạo biến đếm ---
    addi  x11, x0, 0         # x11 = 0 (Biến đếm)
    addi  x12, x0, 10        # x12 = 10 (Giới hạn lặp)
    addi  x16, x0, 1         # Thanh ghi hằng số 1
    
    addi  x20, x0, 0         

consumer_loop:
    beq   x11, x12, end_test # Đủ 10 vòng thì kết thúc

wait_full:
    # Lệnh amoadd.w: Đọc nguyên tử cờ Full.
    amoadd.w  x14, x0, (x18) 
    beq       x14, x0, wait_full  

    # Lệnh amoxor.w: Lật bit cờ Full từ 1 về 0.
    amoxor.w  x0, x16, (x18)   

    # --- CRITICAL SECTION: TIÊU THỤ ---
    lw        x13, 0(x10)        
    add       x20, x20, x13      

    # Lệnh amoxor.w: Lật bit cờ Empty từ 0 lên 1.
    amoxor.w  x0, x16, (x17)   

    addi      x11, x11, 1        
    j         consumer_loop

end_test:
    addi  x26, x0, 1         # x26 = 1 (Báo Done)
spin:
    j     spin