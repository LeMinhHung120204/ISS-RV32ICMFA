# --- KHỞI TẠO ---
    # x8 = Địa chỉ gốc (Target Address). Giả sử 0x80000000
    # x9 = Stride (Bước nhảy) = 1024
    addi  x9, x0, 1024
    
    # x5 = Dữ liệu mẫu (2026)
    addi  x5, x0, 2026

    # ==========================================================
    # BƯỚC 1: Ghi dữ liệu -> Trạng thái MODIFIED (M)
    # ==========================================================
    sw  x5, 0(x8)     # Cache lưu giá trị 2026, Dirty

    # ==========================================================
    # BƯỚC 2: Lấp đầy 3 Way còn lại
    # ==========================================================
    add x18, x8, x9
    lw  x6, 0(x18)    # Way 1 chiếm dụng

    add x19, x18, x9
    lw  x6, 0(x19)    # Way 2 chiếm dụng

    add x20, x19, x9
    lw  x6, 0(x20)    # Way 3 chiếm dụng -> FULL

    # ==========================================================
    # BƯỚC 3: Eviction & Write Back
    # ==========================================================
    add x21, x20, x9
    lw  x6, 0(x21)    
    # -> x8 bị đá ra. 
    # -> Giá trị 2026 (của x8) bị Write Back xuống RAM.

    # === KẾT QUẢ ===
    # Dữ liệu tại địa chỉ x8 (giá trị 2026) đã được ghi xuống Memory.