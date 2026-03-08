.global _boot

.section .text
.org 0x0                  # Bắt đầu code tại địa chỉ 0x0
_boot:
    addi   x10, x0, 4
    addi   x18, x0, 18
    addi   x11, x0, 1
    sw     x10, (x0)
    # 1. Test Atomic Add
    amoadd.w x12, x11, (x0)   # Read 4 -> Add -> Write 5
    lw     x2,  (x0)

    # 4. Test LR/SC (Cực kỳ quan trọng cho hệ thống Dual-core MOESI của bạn)
    # Kiểm tra xem Reservation Set có hoạt động đúng tại địa chỉ 0x100 không
    lr.w    x17, (x0)
    sc.w    x18, x17, (x0)    # x18 = 0 nếu thành công
    sc.w    x18, x17, (x0)    # x18 = 1 nếu that bai

loop: 
    j loop 

# Đặt dữ liệu tại địa chỉ cố định 0x100
.section .data
.org 0x100                     # Data bắt đầu ngay tại 0x100
.align 4
variable:
    .word 0xdeadbeef           # Giá trị khởi tạo tại địa chỉ 0x100