# Test PHT Saturation to Strong Taken
# Loop nhiều lần để counter đạt 11 (Strong Taken)

.text
.globl _start

_start:
    # Khởi tạo
    addi x1, x0, 10         # Loop 10 lần
    addi x2, x0, 0          # Counter
    
loop:
    addi x2, x2, 1          # i++
    bne x2, x1, loop        # Always taken (except last)
                            # Counter: 10->11->11->11 (saturate)
    
    # Kết quả: x2 = 10
    # PHT counter cho branch này = 11 (Strong Taken)
    
    # Test: một branch nữa nên predict correctly
    addi x3, x0, 1
    addi x4, x0, 2
    bne x3, x4, target      # Taken
    
    addi x5, x0, 99         # Should NOT execute
    
target:
    addi x6, x0, 1          # Should execute
    
done:
    beq x0, x0, done
