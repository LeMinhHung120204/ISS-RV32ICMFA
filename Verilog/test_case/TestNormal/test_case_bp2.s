# Test Alternating Pattern (Worst Case for 2-bit Predictor)
# Pattern: T-NT-T-NT-T-NT...
# Expected: PHT counter oscillates between 01 and 10

.text
.globl _start

_start:
    # Khởi tạo
    addi x1, x0, 20         # Total iterations
    addi x2, x0, 0          # Counter
    addi x10, x0, 0         # Even count
    addi x11, x0, 0         # Odd count
    
loop:
    # Check even/odd
    andi x3, x2, 1          # x3 = x2 & 1
    
    # Alternating branch
    beq x3, x0, even        # If even -> taken, if odd -> not-taken
    
    # Odd path
    addi x11, x11, 1        # odd++
    jal x0, next
    
even:
    addi x10, x10, 1        # even++
    
next:
    addi x2, x2, 1          # i++
    bne x2, x1, loop        # Continue loop
    
    # Kết quả: x10 = 10, x11 = 10
    
done:
    beq x0, x0, done
