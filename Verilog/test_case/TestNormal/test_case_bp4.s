# Test Nested Loops (Multiple BTB Entries)
# Kiểm tra BTB lưu nhiều branch targets

.text
.globl _start

_start:
    # Khởi tạo
    addi x1, x0, 3          # Outer loop count
    addi x2, x0, 0          # Outer counter
    
outer_loop:
    addi x3, x0, 4          # Inner loop count
    addi x4, x0, 0          # Inner counter
    
inner_loop:
    addi x4, x4, 1          # j++
    bne x4, x3, inner_loop  # Inner branch (BTB entry 1)
    
    addi x2, x2, 1          # i++
    bne x2, x1, outer_loop  # Outer branch (BTB entry 2)
    
    # Kết quả: 
    # x2 = 3
    # x4 = 4 (last iteration)
    # Total inner iterations = 3 * 4 = 12
    
done:
    beq x0, x0, done
