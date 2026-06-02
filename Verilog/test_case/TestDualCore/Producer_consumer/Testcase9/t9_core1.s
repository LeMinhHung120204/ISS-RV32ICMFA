.text
    .globl _start
_start:
    addi x12, x0, 0x280     # Địa chỉ Data
    addi x11, x0, 20        
    sw x11, 0(x12)          # Ghi 20 vào 0x280
done:
    addi x26, x0, 1         
end_spin:
    jal x0, end_spin