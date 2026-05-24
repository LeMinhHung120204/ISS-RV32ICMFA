.text
    .globl _start
_start:
    # --- Khởi tạo địa chỉ (Dùng lệnh ADDI gốc thay cho LI) ---
    addi x5, x0, 0x200      # Địa chỉ mutex (0x00000200) -> t0
    addi x6, x0, 0x204      # Địa chỉ shared_counter (0x00000204) -> t1
    addi x7, x0, 10         # Số vòng lặp = 10 -> t2
    addi x28, x0, 1         # Giá trị cờ khóa = 1 -> t3

loop:
    # Nếu bộ đếm x7 == 0 (x0 luôn bằng 0), nhảy đến done để kết thúc
    beq x7, x0, done        # Gốc của BEQZ x7, done

acquire_lock:
    # [MOESI Test]: L1 Miss -> Fetch Data
    lr.w x29, (x5)          
    
    # Nếu mutex != 0 (tức là x29 != x0), khóa đang bị chiếm -> quay lại thử lại
    bne x29, x0, acquire_lock # Gốc của BNEZ x29, acquire_lock
    
    # [MOESI Test]: Upgrade to M. 
    sc.w x30, x28, (x5)    # Thử ghi 1 vào mutex. x30 sẽ = 0 nếu thành công
    
    # Nếu sc thất bại (x30 != x0), quay lại thử lại
    bne x30, x0, acquire_lock # Gốc của BNEZ x30, acquire_lock

critical_section:
    lw x31, 0(x6)          # Đọc counter hiện tại
    addi x31, x31, 1       # Tăng 1
    sw x31, 0(x6)          # Ghi lại counter [MOESI: Trạng thái M]

release_lock:
    sw x0, 0(x5)           # Ghi x0 (bằng 0) để nhả khóa
    
    addi x7, x7, -1        # Giảm số vòng lặp đi 1
    jal x0, loop           # Gốc của lệnh J loop (Ghi PC+4 vào x0 để bỏ qua)

done:
    addi x26, x0, 1        # x26 = 1: Báo cáo cho Testbench là Core đã xong
    lw x11, 0(x6)          # [MOESI]: Đọc giá trị counter cuối cùng từ Cache lên x11

end_spin:
    jal x0, end_spin       # Gốc của lệnh J end_spin (Vòng lặp vô hạn chờ Testbench)