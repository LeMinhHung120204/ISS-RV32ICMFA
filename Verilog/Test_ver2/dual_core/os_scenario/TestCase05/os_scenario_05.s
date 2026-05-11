# Group: os_scenario | TestCase: 05 (TC95)
# Description: CSR Read/Write Test
# Validates csrrw, csrrs, and csrrc instructions on the mscratch register.
.section.text
.global _start
_start:
    csrr t0, mhartid
    bnez t0, park_core

    li t1, 0xFFFFFFFF
    csrw mscratch, t1
    
    # Test csrrw
    li t2, 0x12345678
    csrrw t3, mscratch, t2
    bne t3, t1, fail          # t3 should be old value (0xFFFFFFFF)
    
    # Test csrrc (clear bits)
    li t2, 0x00005678
    csrrc t3, mscratch, t2    # mscratch should become 0x12340000
    
    # Test csrrs (set bits)
    li t2, 0x0000ABCD
    csrrs t3, mscratch, t2    # mscratch should become 0x1234ABCD
    
    # Final check
    csrr t4, mscratch
    li t5, 0x1234ABCD
    bne t4, t5, fail

pass_end: li a0, 0; ebreak
fail: li a0, 1; ebreak
park_core: wfi; j park_core
