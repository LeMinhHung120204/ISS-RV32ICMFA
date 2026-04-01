# Hướng dẫn Test Core B và Giải thích Kiến trúc RV32IMF

## Mục lục
1. [Tổng quan Kiến trúc](#tổng-quan-kiến-trúc)
2. [Giải thích chi tiết từng module](#giải-thích-chi-tiết-từng-module)
3. [Cách test trên Vivado](#cách-test-trên-vivado)
4. [Cách xem sóng trên ModelSim](#cách-xem-sóng-trên-modelsim)

---

## 1. Tổng quan Kiến trúc

### Kiến trúc Core (single_core.v / core_b.v)

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              CORE (single_core / core_b)                     │
│                                                                              │
│  ┌────────────────────────────────────────────────────────────────────────┐ │
│  │                         RV32IMF Processor                               │ │
│  │                                                                         │ │
│  │  ┌────────┐   ┌────────┐   ┌────────┐   ┌────────┐   ┌────────┐       │ │
│  │  │   IF   │──▶│   ID   │──▶│   EX   │──▶│   MEM  │──▶│   WB   │       │ │
│  │  │ Fetch  │   │ Decode │   │Execute │   │ Memory │   │WriteBack│       │ │
│  │  └────┬───┘   └───┬────┘   └───┬────┘   └───┬────┘   └────────┘       │ │
│  │       │           │           │           │                            │ │
│  │  PC ──┘     ALU ──┼── RegFile ┘     ┌─────┘                            │ │
│  │  BPU              │                 │                                  │ │
│  │  (Branch          MDU/FPU           │                                  │ │
│  │   Prediction)                       │                                  │ │
│  └─────────────────────────────────────┼──────────────────────────────────┘ │
│                                        │                                     │
│  ┌──────────────────┐         ┌────────▼────────┐                           │
│  │    I-Cache L1    │         │    D-Cache L1   │                           │
│  │  (Instruction)   │         │     (Data)      │                           │
│  │  4-way, 16 sets  │         │  4-way, 16 sets │                           │
│  └────────┬─────────┘         └────────┬────────┘                           │
│           │                            │                                     │
│           └────────────┬───────────────┘                                     │
│                        │                                                     │
│                ┌───────▼───────┐                                             │
│                │    Arbiter    │   (Chia quyền truy cập L2 cho I/D Cache)    │
│                └───────┬───────┘                                             │
│                        │                                                     │
│                ┌───────▼───────┐                                             │
│                │   L2 Cache    │                                             │
│                │  (MOESI FSM)  │◀─── Snoop từ Core khác                     │
│                └───────┬───────┘                                             │
│                        │                                                     │
└────────────────────────┼─────────────────────────────────────────────────────┘
                         │
                    AXI ACE Bus
                         │
                         ▼
              ACE Interconnect (Kết nối 2 core)
```

---

## 2. Giải thích chi tiết từng module

### 2.1 RV32IMF.v - Processor 5-stage Pipeline

**Đây là bộ xử lý chính** với 5 giai đoạn pipeline:

| Giai đoạn | Tên | Chức năng |
|-----------|-----|-----------|
| **IF** | Instruction Fetch | Lấy lệnh từ I-Cache theo địa chỉ PC |
| **ID** | Instruction Decode | Giải mã lệnh, đọc thanh ghi |
| **EX** | Execute | ALU tính toán, MDU nhân chia, FPU floating-point |
| **MEM** | Memory | Đọc/ghi D-Cache |
| **WB** | Write Back | Ghi kết quả về thanh ghi |

**Các module con quan trọng:**
```
RV32IMF
├── PC              # Program Counter
├── IF_ID           # Pipeline register IF→ID
├── ControlUnit     # Giải mã lệnh thành các tín hiệu điều khiển
├── RegFile         # 32 thanh ghi integer (x0-x31)
├── FRegFile        # 32 thanh ghi floating-point (f0-f31)
├── ID_EX           # Pipeline register ID→EX
├── ALU             # Tính toán số học/logic
├── MDU             # Multiply/Divide Unit
├── FPU             # Floating Point Unit
├── EX_MEM          # Pipeline register EX→MEM
├── MEM_WB          # Pipeline register MEM→WB
├── HazardUnit      # Xử lý data hazard, forwarding
└── BranchPredictor # Dự đoán nhánh (GHSR - Global History Shift Register)
```

**Luồng hoạt động:**
```
1. PC → I-Cache → Lệnh (32 bit)
2. Giải mã lệnh → Control signals + Register addresses
3. Đọc thanh ghi → Operands cho ALU/FPU
4. Tính toán kết quả
5. Đọc/Ghi D-Cache (nếu là lệnh load/store)
6. Ghi kết quả về thanh ghi
```

### 2.2 I-Cache L1 (icache.v)

**Chức năng:** Lưu trữ lệnh (instruction) gần CPU để truy cập nhanh

**Cấu trúc:**
- **4-way set-associative**: Mỗi set có 4 cache line
- **16 sets**: Tổng 64 cache lines
- **Cache line**: 512 bits = 16 words = 64 bytes
- **PLRU replacement**: Pseudo-LRU để chọn line thay thế

**Hoạt động:**
```
CPU request addr 0x1000
          │
          ▼
┌─────────────────┐
│  Tách địa chỉ:  │
│  Tag | Index |  │
│  Offset         │
└────────┬────────┘
         │
         ▼
    Kiểm tra 4 ways
         │
    ┌────┴────┐
    │         │
  HIT        MISS
    │         │
    ▼         ▼
Trả lệnh   Request
  ngay     L2 Cache
```

### 2.3 D-Cache L1 (dcache.v)

**Chức năng:** Lưu trữ data gần CPU

**Tương tự I-Cache nhưng có thêm:**
- **Write support**: CPU có thể ghi data
- **Snoop port**: Nhận snoop từ L2 để kiểm tra coherency
- **Dirty bit**: Đánh dấu data đã sửa đổi

**Snoop Port hoạt động:**
```
L2 nhận snoop từ Core khác
          │
          ▼
L2 forward snoop đến D-Cache L1
          │
          ▼
D-Cache kiểm tra tag
          │
    ┌─────┴─────┐
    │           │
  HIT          MISS
    │           │
    ▼           ▼
o_snoop_hit=1  o_snoop_hit=0
o_snoop_data   
o_snoop_dirty
```

### 2.4 L2 Cache (L2_cache.v)

**Chức năng:** Cache lớn hơn, dùng chung cho I-Cache và D-Cache

**Đặc điểm:**
- **4-way set-associative, 32 sets**
- **MOESI protocol**: Modified, Owned, Exclusive, Shared, Invalid
- **ACE interface**: Kết nối với ACE Interconnect

**MOESI States:**
```
Modified (M)  : Data đã sửa, chỉ có ở cache này
Owned (O)     : Data đã sửa, có thể share cho core khác
Exclusive (E) : Data clean, chỉ có ở cache này
Shared (S)    : Data clean, có thể có ở core khác
Invalid (I)   : Không có data hợp lệ
```

### 2.5 ACE Interconnect (ace_interconnect.v)

**Chức năng:** Đảm bảo cache coherency giữa 2 core

**Hoạt động khi Core A đọc:**
```
1. Core A gửi AR request
2. Interconnect gửi Snoop (AC) đến Core B
3. Core B kiểm tra cache, trả lời (CR):
   - crresp[3] = 1: Có data → Gửi qua CD channel
   - crresp[3] = 0: Không có → Lấy từ L3
4. Interconnect forward data về Core A (R channel)
```

---

## 3. Cách test trên Vivado

### Bước 1: Tạo Project

1. Mở Vivado → **Create Project**
2. Chọn **RTL Project**
3. Add source files:
   ```
   Core_B/core_b.v
   Core_B/soc_dual_core.v
   Bus_wrapper/single_core.v
   Bus_wrapper/arbiter.v
   dual_core/ace_interconect.v
   RV32ICMFA/*.v
   Cache/*.v
   Mux/*.v
   Add/*.v
   Mul/*.v
   Div/*.v
   Float/*.v
   BranchPrediction/*.v
   ```

4. Add constraint file (nếu có)
5. Chọn FPGA target (ví dụ: xc7a100t cho Artix-7)

### Bước 2: Run Synthesis

1. Click **Run Synthesis** trong Flow Navigator
2. Chờ synthesis hoàn thành
3. Kiểm tra **Messages** tab để xem warnings/errors

### Bước 3: Run Implementation (optional)

1. Click **Run Implementation**
2. Chờ place & route hoàn thành
3. Xem **Timing Summary** để kiểm tra timing closure

### Bước 4: Generate Bitstream (optional)

1. Click **Generate Bitstream**
2. Download lên FPGA board để test thực tế

---

## 4. Cách xem sóng trên ModelSim

### Bước 1: Tạo Testbench

Tạo file `tb_dual_core.v`:

```verilog
`timescale 1ns/1ps

module tb_dual_core;
    reg clk;
    reg rst_n;
    
    // L3 interface (tạm thời tie-off)
    wire [31:0]  l3_araddr;
    wire         l3_arvalid;
    wire         l3_arready = 1'b1;
    wire [511:0] l3_rdata = 512'd0;
    wire         l3_rvalid = 1'b0;
    wire         l3_rlast = 1'b0;
    wire         l3_rready;
    
    // Instantiate SoC
    soc_dual_core u_soc (
        .ACLK       (clk),
        .ARESETn    (rst_n),
        .m_l3_araddr(l3_araddr),
        .m_l3_arvalid(l3_arvalid),
        .m_l3_arready(l3_arready),
        .m_l3_rdata (l3_rdata),
        .m_l3_rvalid(l3_rvalid),
        .m_l3_rlast (l3_rlast),
        .m_l3_rready(l3_rready)
    );
    
    // Clock: 100MHz
    initial clk = 0;
    always #5 clk = ~clk;
    
    // Reset sequence
    initial begin
        rst_n = 0;
        #100;
        rst_n = 1;
        #10000;
        $finish;
    end
    
    // Dump waveform
    initial begin
        $dumpfile("dual_core.vcd");
        $dumpvars(0, tb_dual_core);
    end
endmodule
```

### Bước 2: Mở ModelSim

1. **File → New → Project**
2. Add tất cả source files và testbench
3. **Compile → Compile All**

### Bước 3: Chạy Simulation

1. **Simulate → Start Simulation**
2. Chọn `work.tb_dual_core`
3. Click **OK**

### Bước 4: Xem Waveform

1. **View → Wave** để mở Wave window
2. Add signals quan trọng:
   ```
   # Clock và Reset
   clk, rst_n
   
   # Core A Pipeline
   u_soc/u_core_A/u_RV32IMF/F_PC         # PC hiện tại
   u_soc/u_core_A/u_RV32IMF/D_Instr      # Lệnh đang decode
   u_soc/u_core_A/u_RV32IMF/E_ALUResult  # Kết quả ALU
   
   # Core B Pipeline
   u_soc/u_core_B/u_RV32IMF/F_PC
   u_soc/u_core_B/u_RV32IMF/D_Instr
   
   # Cache signals
   u_soc/u_core_A/dcache_stall
   u_soc/u_core_A/icache_stall
   
   # ACE Snoop
   u_soc/c0_acvalid                      # Snoop đến Core A
   u_soc/c1_acvalid                      # Snoop đến Core B
   u_soc/c0_crvalid                      # Response từ Core A
   u_soc/c1_crvalid                      # Response từ Core B
   ```

3. **Simulate → Run → Run All** (hoặc F5)
4. Zoom để xem chi tiết waveform

### Bước 5: Debug Pipeline

Để hiểu pipeline đang làm gì:

```
# Xem PC thay đổi mỗi clock
u_soc/u_core_A/u_RV32IMF/F_PC

# Xem lệnh đang được decode
u_soc/u_core_A/u_RV32IMF/D_Instr[6:0]   # Opcode
  - 7'b0110011 = R-type (ADD, SUB, ...)
  - 7'b0010011 = I-type (ADDI, ...)
  - 7'b0000011 = Load (LW, LH, LB)
  - 7'b0100011 = Store (SW, SH, SB)
  - 7'b1100011 = Branch (BEQ, BNE, ...)
  - 7'b1101111 = JAL
  - 7'b1100111 = JALR

# Xem stall
u_soc/u_core_A/u_RV32IMF/HazardUnit_inst/F_Stall
u_soc/u_core_A/u_RV32IMF/HazardUnit_inst/D_Stall
```

---

## Tóm tắt

### Flow test đơn giản:

```
1. Vivado: Add source → Synthesis → Check errors
2. ModelSim: Add files → Compile → Simulate → Wave
3. Debug: Xem PC, Instr, Stall, Cache miss
```

### Tín hiệu quan trọng cần monitor:

| Signal | Ý nghĩa |
|--------|---------|
| `F_PC` | Địa chỉ lệnh hiện tại |
| `D_Instr` | Lệnh đang decode |
| `dcache_stall` | D-Cache đang miss |
| `icache_stall` | I-Cache đang miss |
| `c0_acvalid` | Có snoop đến Core A |
| `c0_crresp[3]` | Core A có data để share |
