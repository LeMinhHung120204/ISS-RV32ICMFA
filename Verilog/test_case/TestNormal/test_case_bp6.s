# Test Forward vs Backward Branches
# Forward branches thường not-taken, Backward thường taken

.text
.globl _start

_start:
    # Test 1: Forward branch (usually not-taken)
    addi x1, x0, 5
    addi x2, x0, 10
    
    bge x1, x2, forward     # Forward, not-taken (5 < 10)
    addi x3, x0, 1          # Should execute
    jal x0, backward_test
    
forward:
    addi x4, x0, 99         # Should NOT execute
    
backward_test:
    # Test 2: Backward branch (usually taken)
    addi x5, x0, 3
    addi x6, x0, 0
    
loop:
    addi x6, x6, 1          # i++
    bne x6, x5, loop        # Backward, taken (2 lần)
    
    # Kết quả:
    # x3 = 1 (forward executed)
    # x4 = 0 (forward NOT executed)
    # x6 = 3
    
done:
    beq x0, x0, done
