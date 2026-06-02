.text
    .globl _start
_start:
    addi x12, x0, 0x280     
    addi x14, x0, 10        # Tạo delay 10 vòng
delay:
    addi x14, x14, -1
    bne x14, x0, delay      
    
    lw x11, 0(x12)          # Đọc 0x280 (Kỳ vọng x11 = 20)
done:
    addi x26, x0, 1         
end_spin:
    jal x0, end_spin