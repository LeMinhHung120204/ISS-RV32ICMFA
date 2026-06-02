.text
    .globl _start
_start:
    addi x5, x0, 0x200      # Cờ báo hiệu
    addi x6, x0, 0x204      # Dữ liệu dùng chung
    
    addi x11, x0, 10        # Giá trị = 10
    sw x11, 0(x6)           # Ghi 10 vào 0x204
    
    addi x7, x0, 1          
    sw x7, 0(x5)            # Bật cờ = 1 tại 0x200
done:
    addi x26, x0, 1         
end_spin:
    jal x0, end_spin