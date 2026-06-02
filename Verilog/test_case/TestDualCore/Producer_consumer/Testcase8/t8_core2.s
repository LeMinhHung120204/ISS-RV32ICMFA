.text
    .globl _start
_start:
    addi x12, x0, 0x240     
    addi x13, x0, 0x244     
    addi x14, x0, 1         
wait_flag:
    lw x15, 0(x12)          
    bne x15, x14, wait_flag # Chờ Flag (x15) == 1
    
    lw x11, 0(x13)          # Lấy dữ liệu (Kỳ vọng x11 = 10)
done:
    addi x26, x0, 1         
end_spin:
    jal x0, end_spin