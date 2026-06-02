.text
    .globl _start
_start:
    addi x12, x0, 0x300     # Core 0 dùng địa chỉ 0x300
    addi x11, x0, 50        
    sw x11, 0(x12)          
    lw x11, 0(x12)          # Ghi xong đọc lại (Kỳ vọng x11 = 50)
done:
    addi x26, x0, 1         
end_spin:
    jal x0, end_spin