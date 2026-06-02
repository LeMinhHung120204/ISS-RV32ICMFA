.text
    .globl _start
_start:
    addi x12, x0, 0x380
    
    # Delay chờ Core 0 thực hiện xong Atomic
    addi x14, x0, 15
delay:
    addi x14, x14, -1
    bne x14, x0, delay

    lw x11, 0(x12)          # Đọc lại địa chỉ 0x380 (Kỳ vọng x11 = 60)

done:
    addi x26, x0, 1         
end_spin:
    jal x0, end_spin