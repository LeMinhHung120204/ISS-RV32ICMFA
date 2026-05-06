# Group: rv32i_basic | TestCase: 04
# Description: Load-Use Hazard & Sign Extension Corner Case
# Tests pipeline stall and correct sign extension for lb vs lbu.
.section.text
.global _start
_start:
    csrr t0, mhartid
    bnez t0, park_core

    la a0, test_data
    
    # Corner case: Load byte with MSB=1 (0x80)
    lb t1, 0(a0)         # Must sign-extend to 0xFFFFFF80
    add t2, t1, x0       # Pipeline MUST STALL
    
    lbu t3, 0(a0)        # Must zero-extend to 0x00000080
    add t4, t3, x0       # Pipeline MUST STALL
    
    li x31, 0xFFFFFF80
    bne t2, x31, fail
    li x31, 0x00000080
    bne t4, x31, fail
pass:
    li a0, 0
    ebreak
fail:
    li a0, 1
    ebreak
park_core:
    wfi
    j park_core

.section.data
.align 4
test_data: 
  .byte 0x80
