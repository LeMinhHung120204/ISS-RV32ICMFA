.text
    .globl _start
_start:
    addi x12, x0, 0x2A0     
    addi x11, x0, 40        
    
    addi x14, x0, 15        
delay:
    addi x14, x14, -1
    bne x14, x0, delay      
    
    sw x11, 0(x12)          # Ghi 40 vào, bắt Cache Core 0 phải Invalidate
done:
    addi x26, x0, 1         
end_spin:
    jal x0, end_spin