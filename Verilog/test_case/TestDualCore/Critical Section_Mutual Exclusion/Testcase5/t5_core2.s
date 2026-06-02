.text
    .globl _start
_start:
    addi x12, x0, 0x3A0     
    addi x13, x0, 0x3A4     
    addi x15, x0, 1
    
wait_c0:
    lw x17, 0(x13)
    bne x17, x15, wait_c0   # Chờ Core 0 đặt chỗ xong (Cờ = 1)
    
    addi x18, x0, 10
    sw x18, 0(x12)          # Core 1 GHI ĐÈ -> Gửi Invalidate tới L1 của Core 0
    
    addi x16, x0, 2
    sw x16, 0(x13)          # Báo lại Core 0 là đã phá xong (Cờ = 2)
    
    addi x11, x0, 70        # Chỉnh x11 cho khớp file log
done:
    addi x26, x0, 1         
end_spin:
    jal x0, end_spin