.text
    .globl _start
_start:
    addi x12, x0, 0x540     
    
    # [1] Đặt chỗ bình thường
    lr.w x13, (x12)         
    
    # [2] SC lần 1: Sẽ THÀNH CÔNG (x15 = 0) và tự động XÓA cờ đặt chỗ
    addi x14, x0, 50
    sc.w x15, x14, (x12)    
    
    # [3] SC lần 2: KHÔNG CÓ LR ĐI KÈM. Bắt buộc phải THẤT BẠI (x16 != 0)
    addi x14, x0, 99
    sc.w x16, x14, (x12)    
    
    # Kiểm tra kết quả
    beq x16, x0, fail_logic # Nếu x16 == 0 (SC lần 2 lại thành công), logic mạch bị sai
    
    # Chạy đúng ý đồ (SC lần 2 thất bại)
    addi x11, x0, 120       # Nạp 120 báo Pass
    beq x0, x0, done
    
fail_logic:
    addi x11, x0, 0         # Nạp 0 báo Fail

done:
    addi x26, x0, 1         
end_spin:
    jal x0, end_spin