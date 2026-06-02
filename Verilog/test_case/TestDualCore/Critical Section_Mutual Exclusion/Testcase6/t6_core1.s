.text
    .globl _start
_start:
    addi x12, x0, 0x3C0     # Biến đếm dùng chung ban đầu bằng 0
    
retry_c0:
    lr.w x13, (x12)         # Đọc giá trị hiện tại
    addi x13, x13, 40       # Cộng thêm 40
    sc.w x14, x13, (x12)    # Cố gắng ghi lại
    bne x14, x0, retry_c0   # Nếu SC trượt (x14 != 0), quay lại retry_c0
    
    # Tạo Delay để chờ Core 1 cũng cộng xong phần của nó
    addi x15, x0, 20
delay_c0:
    addi x15, x15, -1
    bne x15, x0, delay_c0
    
    lw x11, 0(x12)          # Đọc giá trị cuối (Kỳ vọng 40 + 40 = 80)

done:
    addi x26, x0, 1         
end_spin:
    jal x0, end_spin