.text
    .globl _start
_start:
    addi x12, x0, 0x500     # Data A (Word 0 của Cache Line)
    addi x13, x0, 0x508     # Cờ đồng bộ
    
    # [1] Core 0 ghi dữ liệu -> Chiếm quyền M (Modified) cho toàn bộ Cache Line
    addi x14, x0, 110
    sw x14, 0(x12)          
    
    # [2] Bật cờ báo Core 1
    addi x15, x0, 1
    sw x15, 0(x13)          
    
    # [3] Chờ Core 1 ghi xong
    addi x16, x0, 2
wait_c1:
    lw x17, 0(x13)
    bne x17, x16, wait_c1   
    
    # [4] Lúc này Core 1 đã giật mất quyền M của Cache line.
    # Lệnh Load này sẽ ép Core 0 gửi Snoop Read để xin lại dữ liệu từ L1 của Core 1 (Chuyển sang O/S).
    lw x11, 0(x12)          # Kỳ vọng x11 = 110
    
done:
    addi x26, x0, 1         
end_spin:
    jal x0, end_spin