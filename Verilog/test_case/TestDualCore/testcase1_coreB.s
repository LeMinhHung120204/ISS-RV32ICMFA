    .section .text.init
    .globl _start
_start:
    j base_addr_1

    .text
base_addr_1:
    addi  x1, x0, 0x124      # x1 = 0x124
    slli  x1, x1, 8          # x1 = 0x12400 (Vùng Shared Data dành cho Core B)
    addi  x2, x0, 0          # x2 = 0 (Biến đếm vòng lặp i = 0)
    addi  x3, x0, 16         # x3 = 16 (Giới hạn vòng lặp)

store_loop1:                 # Vòng lặp lưu 16 Word vào từ địa chỉ 0x2400 đến 0x243C
    beq   x2, x3, base_addr_2 # Nếu i == 16 thì thoát sang base_addr_2
    lui   x6, 0x00ABC        # x6 = 0x00ABC000
    ori   x6, x6, 0x7EF      # x6 = 0x00ABC7EF (Giá trị hằng số seed, giống CPU A)
    xor   x5, x5, x6         # x5 = x5 ^ 0x00ABC7EF (Tạo giá trị giả ngẫu nhiên)
    andi  x5, x5, -16        # x5 = x5 & 0xFFFFFFF0 (Xóa 4 bit cuối bằng 0)
    or    x4, x5, x2         # x4 = x5 | i (Ghép biến đếm i vào 4 bit cuối để tạo data)
    slli  x5, x2, 2          # x5 = i * 4 (Tính offset cho địa chỉ bộ nhớ)
    add   x6, x1, x5         # x6 = 0x2400 + i*4 (Tính địa chỉ thực tế cần ghi)
    sw    x4, 0(x6)          # Mem[0x2400 + i*4] = x4 (Ghi dữ liệu vào D-Cache/Memory)
    addi  x2, x2, 1          # i = i + 1
    jal   x0, store_loop1    # Lặp lại store_loop1

base_addr_2:
    addi  x2, x0, 0          # x2 = 0 (Reset biến đếm i = 0)
    addi  x3, x0, 16         # x3 = 16 (Giới hạn vòng lặp)
    addi  x22, x0, -1        # x22 = 0xFFFFFFFF (Khởi tạo toàn 1 để chuẩn bị cho phép AND)
    # THÊM ĐỂ RESET:
    addi  x21, x0, 0
    addi  x23, x0, 0
    addi  x24, x0, 0
    addi  x25, x0, 0

load_loop_2:                 # Vòng lặp đọc lại 16 giá trị từ 0x2400 để test Read Hit
    beq   x2, x3, base_addr_3 # Nếu i == 16 thì thoát sang base_addr_3
    slli  x4, x2, 2          # x4 = i * 4 (Tính offset)
    add   x5, x1, x4         # x5 = 0x2400 + i*4 (Tính địa chỉ)
    lw    x6, 0(x5)          # x6 = Word tại [x5]
    lh    x7, 0(x5)          # x7 = Halfword tại [x5]
    lhu   x8, 0(x5)          # x8 = Unsigned Halfword tại [x5]
    lb    x9, 0(x5)          # x9 = Byte tại [x5]
    lbu   x10, 0(x5)         # x10 = Unsigned Byte tại [x5]
    or    x21, x21, x6       # x21 = Tích lũy phép OR của tất cả các Word
    and   x22, x22, x7       # x22 = Tích lũy phép AND của tất cả các Halfword 
    xor   x23, x23, x8       # x23 = Tích lũy phép XOR của tất cả các Unsigned Halfword
    add   x24, x24, x9       # x24 = Tổng (ADD) của tất cả các Signed Byte
    add   x25, x25, x10      # x25 = Tổng (ADD) của tất cả các Unsigned Byte
    addi  x2, x2, 1          # i = i + 1
    jal   x0, load_loop_2    # Lặp lại load_loop_2

base_addr_3:                 # Ghi vào 0x2800 (Có thể để làm đầy Way Cache)
    addi  x1, x0, 0x128      # x1 = 0x128
    slli  x1, x1, 8          # x1 = 0x12800
    lui   x5, 0x12345        # x5 = 0x12345000
    ori   x5, x5, 0x678      # x5 = 0x12345678
    sw    x5, 0(x1)          # Mem[0x2800] = 0x12345678

base_addr_4:                 # Ghi vào 0x2C00
    addi  x1, x0, 0x12C      # x1 = 0x12C
    slli  x1, x1, 8          # x1 = 0x12C00
    lui   x5, 0xCAFEB        # x5 = 0xCAFEB000
    ori   x5, x5, 0x0BE      # x5 = 0xCAFEB0BE
    sw    x5, 0(x1)          # Mem[0x2C00] = 0xCAFEB0BE

base_addr_5:                 # Ghi vào 0x0C00
    addi  x1, x0, 0x10C      # x1 = 0x10C
    slli  x1, x1, 8          # x1 = 0x10C00
    lui   x5, 0x13579        # x5 = 0x13579000
    ori   x5, x5, 0x0E0      # x5 = 0x135790E0
    sw    x5, 0(x1)          # Mem[0x0C00] = 0x135790E0

base_addr_6:                 # Ghi vào 0x0C40 (Test truy cập Set 1 theo mô tả)
    addi  x1, x0, 0x10C      # x1 = 0x10C
    slli  x1, x1, 8          # x1 = 0x10C00
    addi  x1, x1, 0x40       # x1 = 0x10C00 + 0x40 = 0x10C40
    lui   x5, 0x2468A        # x5 = 0x2468A000
    ori   x5, x5, 0x0CE      # x5 = 0x2468A0CE
    sw    x5, 0(x1)          # Mem[0x0C40] = 0x2468A0CE

base_addr_7:
    addi  x1, x0, 0x24       # x1 = 0x24
    slli  x1, x1, 8          # x1 = 0x2400 (Quay lại test Read Hit cho Block 0x2400)
    addi  x2, x0, 0          # x2 = 0
    addi  x3, x0, 16         # x3 = 16
    addi  x27, x0, -1        # x27 = 0xFFFFFFFF (Chuẩn bị thanh ghi để AND)
    # THÊM ĐỂ RESET:
    addi  x26, x0, 0
    addi  x28, x0, 0
    addi  x29, x0, 0
    addi  x30, x0, 0

load_loop_7:                 # Lặp lại việc đọc 16 giá trị từ 0x2400 giống load_loop_2
    beq   x2, x3, quick_check
    slli  x4, x2, 2          # x4 = i * 4
    add   x5, x1, x4         # x5 = 0x2400 + i*4
    lw    x6, 0(x5)
    lh    x7, 0(x5)
    lhu   x8, 0(x5)
    lb    x9, 0(x5)
    lbu   x10, 0(x5)
    or    x26, x26, x6       # x26 = Kết quả tích lũy OR lần 2
    and   x27, x27, x7       # x27 = Kết quả tích lũy AND lần 2
    xor   x28, x28, x8       # x28 = Kết quả tích lũy XOR lần 2
    add   x29, x29, x9       # x29 = Kết quả tích lũy ADD (signed byte) lần 2
    add   x30, x30, x10      # x30 = Kết quả tích lũy ADD (unsigned byte) lần 2
    addi  x2, x2, 1
    jal   x0, load_loop_7

quick_check:                 # SO SÁNH CHÉO XEM DATA CÓ BỊ MẤT MÁT KHÔNG
    xor   x11, x21, x26      # Expected: x11 = 0 (x21 == x26)
    xor   x12, x22, x27      # Expected: x12 = 0 (x22 == x27)
    xor   x13, x23, x28      # Expected: x13 = 0 (x23 == x28)
    xor   x14, x24, x29      # Expected: x14 = 0 (x24 == x29)
    xor   x15, x25, x30      # Expected: x15 = 0 (x25 == x30)
end_program:                 # Chương trình hoàn thành. Các thanh ghi x11 -> x15 phải bằng 0.