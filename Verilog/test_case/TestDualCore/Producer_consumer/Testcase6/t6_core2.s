.text
    .globl _start
_start:
    addi x5, x0, 0x200      # Cờ báo hiệu
    addi x6, x0, 0x204      # Dữ liệu dùng chung
    addi x7, x0, 1          
wait_flag:
    lw x29, 0(x5)           
    bne x29, x7, wait_flag  # Chờ cờ 0x200 == 1
    
    lw x11, 0(x6)           # Đọc 0x204 vào x11 (Kỳ vọng x11 = 20)
done:
    addi x26, x0, 1         
end_spin:
    jal x0, end_spin