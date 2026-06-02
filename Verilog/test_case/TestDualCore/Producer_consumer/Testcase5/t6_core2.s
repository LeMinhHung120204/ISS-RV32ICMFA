.text
    .globl _start
_start:
    # --- Khởi tạo địa chỉ ---
    addi x5, x0, 0x200      # Địa chỉ cờ báo hiệu (Flag)
    addi x6, x0, 0x204      # Địa chỉ biến dùng chung (Shared Data)
    addi x7, x0, 1          # Giá trị cờ đích cần chờ là 1

wait_flag:
    # Đọc cờ liên tục, kiểm tra Cache Coherence
    lw x29, 0(x5)           # Đọc địa chỉ 0x200
    bne x29, x7, wait_flag  # Nếu cờ chưa bằng 1 thì quay lại chờ tiếp

    # Cờ đã được bật, tiến hành đọc data
    lw x11, 0(x6)           # Đọc Shared Data (Sẽ lấy được giá trị 20)

done:
    addi x26, x0, 1         # Báo cho Testbench là Core 1 đã xong

end_spin:
    jal x0, end_spin        # Vòng lặp vô hạn chờ Testbench tắt