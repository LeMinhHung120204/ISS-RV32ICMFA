.text
    .globl _start
_start:
    addi x12, x0, 0x2A0     
    addi x14, x0, 40        # Đích cần tìm
spin_read:
    lw x11, 0(x12)          
    bne x11, x14, spin_read # Lặp tới khi x11 = 40 thì thoát
done:
    addi x26, x0, 1         
end_spin:
    jal x0, end_spin