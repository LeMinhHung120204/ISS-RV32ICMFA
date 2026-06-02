.text
    .globl _start
_start:
    addi x12, x0, 0x380     # Địa chỉ kiểm tra
    
    # Bắt đầu Atomic
    lr.w x13, (x12)         # Đặt chỗ (Reserve) địa chỉ 0x380
    addi x14, x0, 60        # Giá trị muốn ghi
    sc.w x15, x14, (x12)    # Thực hiện ghi cso điều kiện. x15 sẽ = 0 nếu thành công
    
    # Nếu x15 != 0 (thất bại), bỏ qua việc nạp kết quả
    bne x15, x0, done       
    addi x11, x0, 60        # Thành công: Nạp 60 vào x11

done:
    addi x26, x0, 1         
end_spin:
    jal x0, end_spin