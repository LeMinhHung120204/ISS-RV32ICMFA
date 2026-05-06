# Group: benchmark | TestCase: 09
# Description: Matrix Transpose (2x2)
# Tests strided memory access patterns without relying on hardware multiplication.
.section.text
.global _start
_start:
    csrr t0, mhartid
    bnez t0, park_core

    la a0, mat_src
    la a1, mat_dst

    # Transpose 2x2 Matrix:
    # dst = src
    lw t0, 0(a0)
    sw t0, 0(a1)

    # dst[1] = src[1]
    lw t0, 8(a0)
    sw t0, 4(a1)

    # dst[1] = src[1]
    lw t0, 4(a0)
    sw t0, 8(a1)

    # dst[1][1] = src[1][1]
    lw t0, 12(a0)
    sw t0, 12(a1)

check:
    lw t1, 4(a1)         # Should be 3
    li t2, 3
    bne t1, t2, fail
    
    lw t1, 8(a1)         # Should be 2
    li t2, 2
    bne t1, t2, fail

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
# Original Matrix: [1, 2]
#                  [3, 4]
mat_src:.word 1, 2, 3, 4   
mat_dst:.space 16
