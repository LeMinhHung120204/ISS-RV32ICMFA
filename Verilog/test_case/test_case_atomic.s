.global _boot

.section .text
.org 0x0                  # Bắt đầu code tại địa chỉ 0x0
_boot:
    addi   x10,  x0, 4
    addi   x11, x0, 1
    sw     x10, (x0)
    # 1. Test Atomic Add
    amoadd.w x12, x11, (x0)   # Read 4 -> Add -> Write 5
    lw     x2,  (x0)

    # 2. Test Atomic Swap
    li      x13, 0xAAAA5555
    amoswap.w x14, x13, (x10)

    # 3. Test Atomic Max
    li      x15, 0xBBBBBBBB
    amomax.w x16, x15, (x10)

    # 4. Test LR/SC (Cực kỳ quan trọng cho hệ thống Dual-core MOESI của bạn)
    # Kiểm tra xem Reservation Set có hoạt động đúng tại địa chỉ 0x100 không
    lr.w    x17, (x10)
    sc.w    x18, x17, (x10)    # x18 = 0 nếu thành công

loop: 
    j loop 

# Đặt dữ liệu tại địa chỉ cố định 0x100
.section .data
.org 0x100                     # Data bắt đầu ngay tại 0x100
.align 4
variable:
    .word 0xdeadbeef           # Giá trị khởi tạo tại địa chỉ 0x100