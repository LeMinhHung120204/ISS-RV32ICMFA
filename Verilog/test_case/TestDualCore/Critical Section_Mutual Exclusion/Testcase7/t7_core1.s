.text
    .globl _start
_start:
    addi x12, x0, 0x400     # Mutex Lock (0 = Mở, 1 = Đóng)
    addi x13, x0, 0x404     # Data
    addi x14, x0, 1         # Giá trị cờ khóa

lock_c0:
    lr.w x15, (x12)         
    bne x15, x0, lock_c0    # Nếu Khóa != 0, xoay vòng chờ
    sc.w x16, x14, (x12)    # Thử đóng khóa lại
    bne x16, x0, lock_c0    # Nếu trượt, quay lại chờ
    
    # --- Critical Section ---
    addi x11, x0, 90        
    sw x11, 0(x13)          # Ghi 90 vào Data
    
    # --- Release Lock ---
    sw x0, 0(x12)           # Mở khóa bằng lệnh Store bình thường

done:
    addi x26, x0, 1         
end_spin:
    jal x0, end_spin