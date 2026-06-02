.text
    .globl _start
_start:
    addi x12, x0, 0x400     
    addi x13, x0, 0x404     
    addi x14, x0, 1         
    
    # Tạo delay để Core 0 lấy khóa trước
    addi x17, x0, 5
delay_start:
    addi x17, x17, -1
    bne x17, x0, delay_start

lock_c1:
    lr.w x15, (x12)         
    bne x15, x0, lock_c1    
    sc.w x16, x14, (x12)    
    bne x16, x0, lock_c1    
    
    # --- Critical Section ---
    lw x11, 0(x13)          # Đọc Data (Sẽ lấy được 90 do Core 0 để lại)
    
    # --- Release Lock ---
    sw x0, 0(x12)           

done:
    addi x26, x0, 1         
end_spin:
    jal x0, end_spin