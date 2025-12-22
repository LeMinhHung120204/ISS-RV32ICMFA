# Khởi tạo giá trị
    addi x1, x0, 20      # x1 = 20 (Số lần lặp tổng cộng)
    addi x2, x0, 0       # x2 = 0  (Biến đếm i)
    addi x10, x0, 0      # x10 để đếm số lần nhánh CHẴN được thực hiện
    addi x11, x0, 0      # x11 để đếm số lần nhánh LẺ được thực hiện

loop_start:
    # --- TEST CASE 1: Pattern xen kẽ (Alternating) ---
    # Kiểm tra tính chẵn lẻ của x2 để tạo pattern T-NT-T-NT
    andi x3, x2, 1       # x3 = x2 & 1 (Lấy bit cuối cùng)
    
    # Branch A: Nhánh này sẽ xen kẽ: Taken -> Not Taken -> Taken...
    # Nếu x3 == 0 (số chẵn) -> Nhảy đến is_even (Taken)
    # Nếu x3 == 1 (số lẻ)  -> Không nhảy (Not Taken)
    beq x3, x0, is_even  
    
    # Trường hợp LẺ (Not Taken path của Branch A)
    addi x11, x11, 1     # Tăng biến đếm lẻ
    jal x0, next_iter    # Nhảy không điều kiện đến lần lặp tiếp theo

is_even:
    # Trường hợp CHẴN (Taken path của Branch A)
    addi x10, x10, 1     # Tăng biến đếm chẵn
    # (Fall through xuống next_iter)

next_iter:
    addi x2, x2, 1       # i++

    # --- TEST CASE 2: Vòng lặp (Loop Saturation) ---
    # Branch B: Backward Branch
    # Đây là nhánh "Strongly Taken". Nó sẽ Taken 19 lần và Not Taken 1 lần cuối.
    # Mục tiêu: Kiểm tra xem bộ đếm bão hòa (2-bit counter) có giữ trạng thái 11 hoặc 10 không.
    bne x2, x1, loop_start 

exit:
    # Kết thúc
    add x20, x10, x11    # x20 = Total iterations (nên bằng 20)
    beq x0, x0, exit     # Infinite loop