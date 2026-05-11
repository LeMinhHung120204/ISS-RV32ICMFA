# Group: benchmark | TestCase: 10
# Description: Fletcher-16 Checksum
# Tests heavy ALU accumulation, shifting, and bitwise masking.
.section.text
.global _start
_start:
    csrr t0, mhartid
    bnez t0, park_core

    la a0, data_stream
    li a1, 5             # Length
    li t0, 0             # sum1
    li t1, 0             # sum2

checksum_loop:
    lb t2, 0(a0)
    
    add t0, t0, t2       # sum1 = (sum1 + data)
    andi t0, t0, 0xFF    # modulo 255 approximation (bitwise 256 for test)
    
    add t1, t1, t0       # sum2 = (sum2 + sum1)
    andi t1, t1, 0xFF
    
    addi a0, a0, 1
    addi a1, a1, -1
    bnez a1, checksum_loop

    # Combine sum2 and sum1 into checksum
    slli t1, t1, 8
    or a2, t1, t0

check:
    # Expected result for bytes 1,2,3,4,5
    # sum1: 15 (0x0F)
    # sum2: 35 (0x23)
    # Total: 0x230F
    li t3, 0x230F
    bne a2, t3, fail

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
data_stream:.byte 1, 2, 3, 4, 5
