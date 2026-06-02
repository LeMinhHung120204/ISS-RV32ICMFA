.text
    .globl _start
_start:
    addi x12, x0, 0x240     # Cờ báo hiệu (Flag)
    addi x13, x0, 0x244     # Dữ liệu dùng chung (Data)
    
    addi x11, x0, 10        
    sw x11, 0(x13)          # Ghi 10 vào Data (0x244)
    
    addi x14, x0, 1         
    sw x14, 0(x12)          # Bật cờ = 1 tại Flag (0x240)
done:
    addi x26, x0, 1         
end_spin:
    jal x0, end_spin