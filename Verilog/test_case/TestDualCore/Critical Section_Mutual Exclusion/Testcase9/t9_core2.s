.text
    .globl _start
_start:
    addi x12, x0, 0x504     # Data B (Word 1 - Cùng Cache Line với Data A)
    addi x13, x0, 0x508     # Cờ đồng bộ
    
    # [1] Chờ Core 0 ghi xong
    addi x15, x0, 1
wait_c0:
    lw x17, 0(x13)
    bne x17, x15, wait_c0   
    
    # [2] Core 1 ghi vào Data B -> Ép Invalidate L1 của Core 0, giật quyền M về Core 1
    addi x14, x0, 110
    sw x14, 0(x12)          
    
    # [3] Báo Core 0 đã ghi xong
    addi x16, x0, 2
    sw x16, 0(x13)          
    
    lw x11, 0(x12)          # Kỳ vọng x11 = 110

done:
    addi x26, x0, 1         
end_spin:
    jal x0, end_spin