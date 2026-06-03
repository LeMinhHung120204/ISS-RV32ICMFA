# Hệ thống Kiểm thử Tự động & Mô phỏng cho Core RV32I / RV32A (ISS-RV32ICMFA)

Tài liệu này cung cấp hướng dẫn chi tiết về kiến trúc mô phỏng, các công cụ được sử dụng, cách thức hoạt động của Testbench, và cách thực hiện kiểm thử (chạy tự động hàng loạt hoặc chạy đơn lẻ có xem dạng sóng sóng) cho dự án CPU RV32ICMFA.

---

## 1. Công cụ & Yêu cầu hệ thống (Tools & Prerequisites)

Dự án hỗ trợ đồng thời 2 công cụ mô phỏng để phục vụ các mục đích khác nhau:

1. **Xilinx Vivado (`xvlog`, `xelab`, `xsim`)**
   - **Mục đích:** Chạy tự động toàn bộ bộ test RISC-V với tốc độ rất cao.
   - **Script sử dụng:** `run_all_tests.ps1`
   - *Lưu ý:* Script hiện cấu hình thư mục mặc định là `C:\Xilinx\Vivado\2022.2\bin\`. Bạn có thể thay đổi đường dẫn này trong script nếu bạn đang sử dụng phiên bản Vivado khác.

2. **Icarus Verilog (`iverilog`, `vvp`) & GTKWave**
   - **Mục đích:** Chạy mô phỏng từng test case đơn lẻ, xuất file `.vcd` và tự động mở phần mềm GTKWave để debug dạng sóng tín hiệu theo thời gian thực.
   - **Script sử dụng:** `run_sim.ps1`

3. **Môi trường WSL (Windows Subsystem for Linux)**
   - Cần cài đặt sẵn **Python 3** và **RISC-V GNU Toolchain** (cụ thể là lệnh `riscv64-unknown-elf-objcopy` hoặc `riscv64-linux-gnu-objcopy`) để chuyển đổi mã máy (ELF) sang tệp HEX dùng cho bộ nhớ Verilog.
   - *Cách cài đặt trên Ubuntu WSL:* 
     ```bash
     sudo apt update && sudo apt install -y python3 gcc-riscv64-unknown-elf
     ```
   - **Lưu ý về tập lệnh (ISA):** Vì dự án hiện tại là kiến trúc **RV32** (cụ thể đang focus vào **RV32IA**), bạn chỉ cần quan tâm và sử dụng các bài test có tiền tố `rv32ui-p-*` (RV32 Unprivileged Integer) và `rv32ua-p-*` (RV32 Unprivileged Atomic). Các test RV64 hoặc các extension khác (M, F, D, C...) chưa được hỗ trợ hoàn toàn sẽ gây báo lỗi nếu chạy. Nếu bạn tự build lại bộ `riscv-tests` từ mã nguồn gốc, hãy nhớ chỉ build tập lệnh cho RV32.

---

## 2. Kiến trúc Testbench (`tb_single_core.v`)

Hệ thống mô phỏng sử dụng một Testbench chính là `tb_single_core.v`. 
Testbench này hoạt động theo cơ chế rất đặc biệt để kiểm tra kết quả (Pass/Fail) đối với một kiến trúc CPU chưa hỗ trợ đầy đủ các lệnh hệ thống (Exceptions) hay tập lệnh CSR:

1. **Nạp bộ nhớ:** Testbench sử dụng lệnh `$readmemh` để nạp toàn bộ mã máy từ tệp `hexfile.txt` (được sinh tự động từ script) vào Data Memory và Instruction Memory.
2. **Theo dõi thanh ghi báo trạng thái (`gp` / `x3`):** Mỗi test case trong bộ `riscv-tests` luôn cập nhật chỉ mục của nó (số test case hiện hành) vào thanh ghi `gp`.
3. **Bắt lệnh kết thúc (`ecall`):** 
   - Bất kể CPU hoàn thành thành công tất cả bài test, hay khi CPU tính toán sai và rẽ nhánh vào nhãn báo lỗi (`<fail>`), mã assembly đều thực hiện lệnh `ecall` (opcode `32'h00000073`).
   - Mặc dù bản thân bộ giải mã CPU không hỗ trợ `ecall`, Testbench sẽ trực tiếp "bắt" (intercept) opcode `ecall` tại Pipeline Stage Decode (`D_Instr`).
4. **Đánh giá Đúng/Sai:** 
   - Khi phát hiện `ecall`, Testbench sẽ delay nhẹ (chờ stage Writeback kết thúc) rồi đọc trực tiếp giá trị của thanh ghi `gp` (`x3`) từ file thanh ghi mô phỏng.
   - Nếu `gp == 1` $\rightarrow$ Testbench in ra màn hình `RESULT: PASS`.
   - Nếu `gp != 1` $\rightarrow$ Testbench tự tính ra thứ tự testcase bị sai (bằng công thức `gp >> 1`) và in ra `RESULT: FAIL at test case X`.
   - Để chống trường hợp CPU chạy vòng lặp vô hạn (Infinite Loop), Testbench đồng thời có cờ timeout (giới hạn thời gian); nếu hết thời gian mô phỏng mà CPU chưa gọi `ecall`, nó sẽ báo `RESULT: TIMEOUT`.

---

## 3. Chạy Mô phỏng (Simulation Workflows)

### A. Chạy toàn bộ Test Suite (Auto Test bằng Vivado)

Dùng để đánh giá độ bao phủ và tính đúng đắn toàn cục của CPU đối với tất cả các tập lệnh RV32I & RV32A.

```powershell
.\run_all_tests.ps1
```

- **Quy trình Script thực hiện:** 
  1. Compile 1 lần (`xvlog` + `xelab`) các tệp Verilog được liệt kê trong `filelist.txt`.
  2. Lặp (Loop) qua các bài test thuộc tập lệnh RV32 (`rv32ui-p-*`, `rv32ua-p-*`) có trong thư mục `riscv-tests/isa/`.
  3. Parse tệp ELF sang HEX qua WSL bằng script `elf2hex.py`.
  4. Chạy Simulation (`xsim`).
- **Kết quả:** Tổng hợp Passed / Failed / Timeout tại log cuối tệp `test_results.log`. *(Lưu ý: Đã tự động loại bỏ test `rv32ui-p-fence_i` ra khỏi danh sách quét do kiến trúc chưa hỗ trợ lệnh bộ nhớ này).*

### B. Chạy một bài test đơn & Xem Waveform (Bằng Icarus Verilog)

Khi bạn muốn debug chuyên sâu bằng cách soi từng chu kỳ xung nhịp (clock cycle) với một lệnh hội ngữ cụ thể.

```powershell
.\run_sim.ps1 -ElfFile "riscv-tests/isa/rv32ui-p-add"
```

- **Quy trình Script thực hiện:** 
  1. Parse tệp ELF được chỉ định thành tệp HEX thông qua WSL.
  2. Gọi `iverilog` biên dịch tệp nguồn từ `filelist.txt` tạo file `sim.vvp`.
  3. Gọi `vvp` tạo file dạng sóng `tb_single_core.vcd`.
  4. Tự động bật `gtkwave` hiển thị dạng sóng tín hiệu cho bạn theo dõi.

---

## 4. Hướng dẫn Debug mã Assembly khi Test bị FAIL

Giả sử khi chạy tự động script `run_all_tests.ps1`, bạn nhận được thông báo sau trong cửa sổ hoặc file log:
```text
Running rv32ui-p-sub ... FAIL (Case 12)
```

Bạn muốn biết tại sao Test Case số 12 bị fail, CPU đã nhận đầu vào là gì và kỳ vọng ra sao? Bạn có thể kiểm tra như sau:

1. **Mở file Dump (Disassembly):** Tìm trong thư mục `riscv-tests/isa/` tệp dịch ngược của bộ test đó. Ví dụ: `riscv-tests/isa/rv32ui-p-sub.dump`.
2. **Tìm nhãn Test Case:** Sử dụng công cụ tìm kiếm trong file dump (Ctrl + F), gõ `<test_12>`. Bạn sẽ thấy luồng mã assembly thực tế:
   ```assembly
   8000029c <test_12>:
   8000029c:	00c00193          	li	gp,12             # Nạp số 12 vào gp
   800002a0:	800005b7          	lui	a1,0x80000
   800002a4:	fff58593          	addi	a1,a1,-1          # a1 = 0x7fffffff
   800002a8:	ffff8637          	lui	a2,0xffff8        # a2 = -32768
   800002ac:	40c58733          	sub	a4,a1,a2          # Lệnh đang test
   800002b0:	800083b7          	lui	t2,0x80008
   800002b4:	fff38393          	addi	t2,t2,-1          # t2 = 0x80007fff (Kỳ vọng)
   800002b8:	38771a63          	bne	a4,t2,8000064c <fail> # So sánh: nếu tính sai, rẽ nhánh <fail>
   ```
3. **Đối chiếu trên Waveform:** 
   Sau khi đã xác định được nguyên nhân (ví dụ: ALU tính sai phép `sub` do xử lý tràn bit có dấu không tốt), bạn chạy bài mô phỏng đơn bằng Icarus Verilog:
   ```powershell
   .\run_sim.ps1 -ElfFile "riscv-tests/isa/rv32ui-p-sub"
   ```
   Sau đó trên cửa sổ GTKWave, tìm đến khoảng thời gian mã assembly tại Case 12 đang chạy ở tầng Execute. Đối chiếu giá trị của đầu ra ALU và thanh ghi `a4` (x14) với giá trị kỳ vọng `0x80007fff` để xác định cờ (flag) hoặc logic nào của mạch cộng/trừ bị sai.