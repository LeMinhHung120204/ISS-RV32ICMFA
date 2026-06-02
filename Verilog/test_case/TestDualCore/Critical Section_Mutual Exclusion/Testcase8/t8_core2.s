.text
    .globl _start
_start:
    # Core 1 không cần tương tác trong test này
    # Chỉ cần nạp x11 = 100 để báo log khớp với Core 0
    addi x11, x0, 100       

done:
    addi x26, x0, 1         
end_spin:
    jal x0, end_spin