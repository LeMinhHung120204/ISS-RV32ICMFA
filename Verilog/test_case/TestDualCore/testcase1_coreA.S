    .section .text.init
    .globl _start
_start:
    j base_addr_1

    .text
base_addr_1:
    addi  x1, x0, 0x110      # x1 = 0x110
    slli  x1, x1, 8          # x1 = 0x11000 (Đã nằm trong Shared Data)
    addi  x2, x0, 0          # x2 = 0 (Biến đếm vòng lặp i = 0)
    addi  x3, x0, 16         # x3 = 16 (Giới hạn vòng lặp)

store_loop1:                 # Vòng lặp lưu 16 Word vào từ địa chỉ 0x1000 đến 0x103C
    beq   x2, x3, base_addr_2 # Nếu i == 16 thì thoát sang base_addr_2
    lui   x6, 0x00ABC        # x6 = 0x00ABC000
    ori   x6, x6, 0x7EF      # x6 = 0x00ABC7EF (Giá trị hằng số seed)
    xor   x5, x5, x6         # x5 = x5 ^ 0x00ABC7EF (Tạo giá trị giả ngẫu nhiên)
    andi  x5, x5, -16        # x5 = x5 & 0xFFFFFFF0 (Xóa 4 bit cuối bằng 0)
    or    x4, x5, x2         # x4 = x5 | i (Ghép biến đếm i vào 4 bit cuối để tạo data)
    slli  x5, x2, 2          # x5 = i * 4 (Tính offset cho địa chỉ bộ nhớ, Ghi đè x5)
    add   x6, x1, x5         # x6 = 0x11000 + i*4 (Tính địa chỉ thực tế cần ghi)
    sw    x4, 0(x6)          # Mem[0x11000 + i*4] = x4 (Ghi dữ liệu vào D-Cache/Memory)
    addi  x2, x2, 1          # i = i + 1
    jal   x0, store_loop1    # Lặp lại store_loop1

base_addr_2:
    addi  x2, x0, 0          # x2 = 0 (Reset biến đếm i = 0)
    addi  x3, x0, 16         # x3 = 16 (Giới hạn vòng lặp)
    addi  x12, x0, -1        # x12 = 0xFFFFFFFF (Khởi tạo toàn 1 để chuẩn bị cho phép AND)
    # Thêm các dòng này để reset thanh ghi tích lũy
    addi  x11, x0, 0
    addi  x13, x0, 0
    addi  x14, x0, 0
    addi  x15, x0, 0

load_loop_2:                 # Vòng lặp đọc lại 16 giá trị từ 0x1000 để test Read Hit
    beq   x2, x3, base_addr_3 # Nếu i == 16 thì thoát sang base_addr_3
    slli  x4, x2, 2          # x4 = i * 4 (Tính offset)
    add   x5, x1, x4         # x5 = 0x1000 + i*4 (Tính địa chỉ)
    lw    x6, 0(x5)          # x6 = Word tại [x5]
    lh    x7, 0(x5)          # x7 = Halfword tại [x5] (có mở rộng dấu)
    lhu   x8, 0(x5)          # x8 = Halfword tại [x5] (không mở rộng dấu)
    lb    x9, 0(x5)          # x9 = Byte tại [x5] (có mở rộng dấu)
    lbu   x10, 0(x5)         # x10 = Byte tại [x5] (không mở rộng dấu)
    or    x11, x11, x6       # x11 = Tích lũy phép OR của tất cả các Word
    and   x12, x12, x7       # x12 = Tích lũy phép AND của tất cả các Halfword 
    xor   x13, x13, x8       # x13 = Tích lũy phép XOR của tất cả các Unsigned Halfword
    add   x14, x14, x9       # x14 = Tổng (ADD) của tất cả các Signed Byte
    add   x15, x15, x10      # x15 = Tổng (ADD) của tất cả các Unsigned Byte
    addi  x2, x2, 1          # i = i + 1
    jal   x0, load_loop_2    # Lặp lại load_loop_2

base_addr_3:                 # Test làm đầy Way 1 của Set 0 (Địa chỉ 0x1400)
    addi  x1, x0, 0x114
    slli  x1, x1, 8          # x1 = 0x11400
    lui   x5, 0x12345        # x5 = 0x12345000
    ori   x5, x5, 0x678      # x5 = 0x12345678
    sw    x5, 0(x1)          # Mem[0x1400] = 0x12345678 

base_addr_4:                 # Test làm đầy Way 2 của Set 0 (Địa chỉ 0x1800)
    addi  x1, x0, 0x118
    slli  x1, x1, 8          # x1 = 0x11800
    lui   x5, 0xCAFEB        # x5 = 0xCAFEB000
    ori   x5, x5, 0x0BE      # x5 = 0xCAFEB0BE
    sw    x5, 0(x1)          # Mem[0x1800] = 0xCAFEB0BE

base_addr_5:                 # Test làm đầy Way 3 của Set 0 (Địa chỉ 0x1C00)
    addi  x1, x0, 0x11C
    slli  x1, x1, 8          # x1 = 0x11C00
    lui   x5, 0x13579        # x5 = 0x13579000
    ori   x5, x5, 0x0E0      # x5 = 0x135790E0
    sw    x5, 0(x1)          # Mem[0x1C00] = 0x135790E0

base_addr_6:                 # Test Write-back, PLRUt (Đẩy Block 0x1000 ra khỏi Cache)
    addi  x1, x0, 0x120
    slli  x1, x1, 8          # x1 = 0x12000
    lui   x5, 0x2468A        # x5 = 0x2468A000
    ori   x5, x5, 0x0CE      # x5 = 0x2468A0CE
    sw    x5, 0(x1)          # Mem[0x2000] = 0x2468A0CE 

base_addr_7:
    addi  x1, x0, 0x110      # x1 = 0x110
    slli  x1, x1, 8          # x1 = 0x11000 (Đã nằm trong Shared Data)
    addi  x2, x0, 0          # x2 = 0
    addi  x3, x0, 16         # x3 = 16
    addi  x17, x0, -1        # x17 = 0xFFFFFFFF (Chuẩn bị thanh ghi để AND)
    # Thêm các dòng này để reset thanh ghi tích lũy
    addi  x16, x0, 0
    addi  x18, x0, 0
    addi  x19, x0, 0
    addi  x20, x0, 0

load_loop_7:                 # Lặp lại việc đọc 16 giá trị từ 0x1000 giống hệt load_loop_2
    beq   x2, x3, quick_check
    slli  x4, x2, 2          # x4 = i * 4
    add   x5, x1, x4         # x5 = 0x1000 + i*4
    lw    x6, 0(x5)          
    lh    x7, 0(x5)          
    lhu   x8, 0(x5)          
    lb    x9, 0(x5)          
    lbu   x10, 0(x5)         
    or    x16, x16, x6       # x16 = Kết quả tích lũy OR lần 2
    and   x17, x17, x7       # x17 = Kết quả tích lũy AND lần 2
    xor   x18, x18, x8       # x18 = Kết quả tích lũy XOR lần 2
    add   x19, x19, x9       # x19 = Kết quả tích lũy ADD (signed byte) lần 2
    add   x20, x20, x10      # x20 = Kết quả tích lũy ADD (unsigned byte) lần 2
    addi  x2, x2, 1
    jal   x0, load_loop_7

quick_check:                 # SO SÁNH CHÉO XEM DATA CÓ BỊ MẤT MÁT SAU KHI CACHE EVICTION KHÔNG
    xor   x21, x11, x16      # Expected: x21 = 0 (x11 == x16)
    xor   x22, x12, x17      # Expected: x22 = 0 (x12 == x17)
    xor   x23, x13, x18      # Expected: x23 = 0 (x13 == x18)
    xor   x24, x14, x19      # Expected: x24 = 0 (x14 == x19)
    xor   x25, x15, x20      # Expected: x25 = 0 (x15 == x20)
end_program:                 # Chương trình hoàn thành. Các thanh ghi x21 -> x25 phải bằng 0.