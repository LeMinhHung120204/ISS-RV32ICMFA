# Test Mispredict Recovery
# Train predictor sai, rồi trigger mispredict
# Kiểm tra pipeline flush

.text
.globl _start

_start:
    # Phase 1: Train predictor to "Not Taken"
    addi x1, x0, 5
    addi x2, x0, 10
    addi x3, x0, 0          # Loop counter
    
train:
    beq x1, x2, never       # Not taken (5 != 10)
    addi x3, x3, 1          # Execute này
    addi x4, x0, 3
    bne x3, x4, train       # Loop 3 lần
    jal x0, trigger
    
never:
    addi x5, x0, 99         # Should NEVER execute
    
trigger:
    # Phase 2: Trigger mispredict
    # Branch này giờ TAKEN nhưng predictor nghĩ NOT TAKEN
    addi x1, x0, 10         # Make equal
    addi x2, x0, 10
    
    beq x1, x2, correct     # TAKEN -> MISPREDICT!
    
    # These should be FLUSHED
    addi x6, x0, 88
    addi x7, x0, 77
    
correct:
    # Correct path after flush
    addi x8, x0, 66         # Should execute
    
done:
    beq x0, x0, done
