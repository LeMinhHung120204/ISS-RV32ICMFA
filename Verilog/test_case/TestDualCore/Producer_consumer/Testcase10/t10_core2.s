.text
    .globl _start
_start:
    addi x12, x0, 0x2C4     
    addi x13, x0, 0x2C0     
    addi x16, x0, 1
wait_core0:
    lw x15, 0(x13)
    bne x15, x16, wait_core0 # Chờ cờ = 1
    
    lw x11, 0(x12)          # Đọc Data (Sẽ lấy được 10)
    addi x11, x11, 20       # Cộng thêm 20
    sw x11, 0(x12)          # Ghi lại Data = 30
    
    addi x15, x0, 2
    sw x15, 0(x13)          # Bật cờ = 2
done:
    addi x26, x0, 1         
end_spin:
    jal x0, end_spin