.text
    .globl _start
_start:
    addi x12, x0, 0x420     
    
    # 1. Đặt chỗ
    lr.w x13, (x12)         
    
    # 2. Thực hiện lệnh ghi bình thường xen giữa
    addi x14, x0, 99
    sw x14, 0(x12)          
    
    # 3. Thực hiện SC (Theo thiết kế, lệnh này PHẢI THÀNH CÔNG)
    addi x15, x0, 100
    sc.w x16, x15, (x12)    
    
    # Kiểm tra kết quả SC (x16 phải bằng 0)
    bne x16, x0, fail_logic 
    
    # Thành công: Đọc lại giá trị cuối cùng vào x11 (Kỳ vọng là 100)
    lw x11, 0(x12)          
    beq x0, x0, done
    
fail_logic:
    addi x11, x0, 0         # Nếu SC thất bại (x16 != 0), nạp 0 báo lỗi

done:
    addi x26, x0, 1         
end_spin:
    jal x0, end_spin