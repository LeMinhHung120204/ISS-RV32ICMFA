.text
    .globl _start
_start:
    addi x12, x0, 0x2C4     # Data
    addi x13, x0, 0x2C0     # Flag
    
    addi x14, x0, 10
    sw x14, 0(x12)          # Khởi tạo Data = 10
    
    addi x15, x0, 1
    sw x15, 0(x13)          # Bật cờ = 1
    
    addi x16, x0, 2
wait_core1:
    lw x15, 0(x13)
    bne x15, x16, wait_core1 # Chờ cờ = 2 
    
    lw x11, 0(x12)          # Đọc lại Data (Kỳ vọng x11 = 30)
done:
    addi x26, x0, 1         
end_spin:
    jal x0, end_spin