.text
    .globl _start
_start:
    # --- Khởi tạo địa chỉ ---
    addi x5, x0, 0x200      # Địa chỉ cờ báo hiệu (Flag)
    addi x6, x0, 0x204      # Địa chỉ biến dùng chung (Shared Data)
    
    # --- Ghi dữ liệu và bật cờ ---
    addi x11, x0, 20        # Nạp giá trị đích 20 vào x11
    sw x11, 0(x6)           # Ghi 20 vào Shared Data (0x204)
    
    addi x7, x0, 1          # Giá trị cờ = 1
    sw x7, 0(x5)            # Bật cờ tại địa chỉ 0x200 (Kích hoạt MOESI Monitor)

done:
    addi x26, x0, 1         # Báo cho Testbench là Core 0 đã xong

end_spin:
    jal x0, end_spin        # Vòng lặp vô hạn chờ Testbench tắt