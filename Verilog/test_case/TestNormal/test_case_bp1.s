# Test BTB Basic Hit/Miss
# Kiểm tra BTB hit sau lần đầu tiên
# Expected: Lần 1 = BTB miss, lần 2-5 = BTB hit

.text
.globl _start

_start:
    # Khởi tạo
    addi x1, x0, 5          # Loop count
    addi x2, x0, 0          # Counter
    
# Loop backward branch - Test BTB
loop:
    addi x2, x2, 1          # i++
    bne x2, x1, loop        # Branch: taken 4 lần, not-taken 1 lần
    
    # Kết quả: x2 = 5
    addi x3, x0, 5
    
# Infinite loop
done:
    beq x0, x0, done
