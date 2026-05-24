.text
    .globl _start
_start:
    # --- Khởi tạo địa chỉ (Dùng lệnh ADDI gốc thay cho LI) ---
    addi x5, x0, 0x200      # Địa chỉ mutex (0x00000200)
    addi x6, x0, 0x204      # Địa chỉ shared_counter (0x00000204)
    addi x7, x0, 10         # Số vòng lặp = 10
    addi x28, x0, 1         # Giá trị cờ khóa = 1

loop:
    beq x7, x0, done        # Nếu x7 == 0, kết thúc vòng lặp

acquire_lock:
    # [MOESI Test]: L1 Miss -> Fetch Data
    lr.w x29, (x5)          
    bne x29, x0, acquire_lock # Nếu mutex != 0, thử lại
    
    # [MOESI Test]: Upgrade to M. 
    sc.w x30, x28, (x5)    # Thử ghi 1 vào mutex. x30 sẽ = 0 nếu thành công
    bne x30, x0, acquire_lock # Nếu sc thất bại, thử lại

critical_section:
    lw x31, 0(x6)          
    addi x31, x31, 1       
    sw x31, 0(x6)          

release_lock:
    sw x0, 0(x5)           # Nhả khóa
    
    addi x7, x7, -1        
    jal x0, loop           

done:
    addi x26, x0, 1        # x26 = 1: Báo cho Testbench
    lw x11, 0(x6)          # Nạp counter lên x11

end_spin:
    jal x0, end_spin