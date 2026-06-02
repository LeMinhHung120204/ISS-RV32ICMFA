.text
    .globl _start
_start:
    addi x5, x0, 0x200      
    addi x6, x0, 0x204      
    addi x7, x0, 1          
wait_flag:
    lw x29, 0(x5)           
    bne x29, x7, wait_flag  # Chờ cờ 0x200 == 1
    
    lw x11, 0(x6)           # Lấy dữ liệu (Kỳ vọng x11 = 10)
done:
    addi x26, x0, 1         
end_spin:
    jal x0, end_spin