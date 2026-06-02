.text
    .globl _start
_start:
    # Test này kiểm tra logic nội bộ của Core 0. 
    # Core 1 rảnh rỗi, chỉ nạp x11 cho khớp file log.
    addi x11, x0, 120       

done:
    addi x26, x0, 1         
end_spin:
    jal x0, end_spin