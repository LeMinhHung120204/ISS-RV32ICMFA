.text
    .globl _start
_start:
    addi x12, x0, 0x3A0     # Địa chỉ Data
    addi x13, x0, 0x3A4     # Cờ đồng bộ
    
    lr.w x14, (x12)         # [1] Core 0 đặt chỗ
    
    addi x15, x0, 1
    sw x15, 0(x13)          # [2] Báo cho Core 1: "Tôi đặt chỗ xong rồi, anh phá đi!"
    
    addi x16, x0, 2
wait_c1:
    lw x17, 0(x13)
    bne x17, x16, wait_c1   # [3] Chờ Core 1 ghi đè xong (Cờ = 2)
    
    addi x18, x0, 99
    sc.w x15, x18, (x12)    # [4] Thực hiện SC. MOESI Invalidate phải làm lệnh này THẤT BẠI.
    
    # Nếu x15 == 0 (Thành công sai logic), nhảy thẳng đến done (x11 = 0)
    beq x15, x0, done       
    
    addi x11, x0, 70        # Thất bại đúng như kỳ vọng -> Nạp 70 vào x11

done:
    addi x26, x0, 1         
end_spin:
    jal x0, end_spin