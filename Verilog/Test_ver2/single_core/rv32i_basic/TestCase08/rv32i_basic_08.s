# Group: rv32i_basic | TestCase: 08
# Description: Jump Hazard & Negative Offset JALR
# Tests correct PC calculation and ra saving with negative JALR offsets.
.section.text
.global _start
_start:
    csrr t0, mhartid
    bnez t0, park_core

    jal ra, jump_target_1      # ra saves PC+4
    j fail

jump_target_2:
    j pass                     # Success!

jump_target_1:
    la t1, jump_target_2
    addi t1, t1, 8             # Intentionally overshoot target by 8 bytes
    
    # Corner case: Negative offset in JALR
    jalr x5, t1, -8            # Jump back 8 bytes to exact target_2
    
    j fail

pass:
    li a0, 0
    ebreak
fail:
    li a0, 1
    ebreak
park_core:
    wfi
    j park_core
