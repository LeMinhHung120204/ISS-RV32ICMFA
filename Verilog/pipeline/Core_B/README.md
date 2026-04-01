# Core_B - Dual Core Implementation

## Mô tả
Folder này chứa các module để implement **Core thứ 2** cho hệ thống RV32 IMF Dual Core.

## Cấu trúc

```
Core_B/
├── core_b.v           # Core B (CORE_ID = 1)
├── soc_dual_core.v    # Top-level SoC (Core A + Core B)
└── README.md          # File này
```

## Kiến trúc

```
┌─────────────────────────────────────────────────────────────────────────┐
│                           SoC Dual Core                                 │
│  ┌─────────────────────────────┐  ┌─────────────────────────────┐      │
│  │         CORE A              │  │         CORE B              │      │
│  │        (CORE_ID=0)          │  │        (CORE_ID=1)          │      │
│  │                             │  │                             │      │
│  │   RV32IMF  →  I-Cache L1    │  │   RV32IMF  →  I-Cache L1    │      │
│  │            →  D-Cache L1    │  │            →  D-Cache L1    │      │
│  │                ↓            │  │                ↓            │      │
│  │            Cache L2         │  │            Cache L2         │      │
│  └─────────────┬───────────────┘  └─────────────┬───────────────┘      │
│                └─────────┬──────────────────────┘                      │
│                          │   AXI ACE                                   │
│                    ┌─────▼─────┐                                       │
│                    │    ACE    │                                       │
│                    │Interconn. │                                       │
│                    └─────┬─────┘                                       │
│                          │                                             │
│                    TO L3 CACHE                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

## Files chi tiết

### 1. core_b.v
- **Mục đích:** Core thứ 2 của hệ thống Dual Core
- **CORE_ID:** 1 (để phân biệt với Core A có CORE_ID=0)
- **Cấu trúc giống hệt single_core.v:**
  - RV32IMF processor
  - I-Cache L1
  - D-Cache L1
  - Arbiter
  - L2 Cache với MOESI FSM
  - ACE Snoop channels (AC, CR, CD)

### 2. soc_dual_core.v
- **Mục đích:** Top-level kết nối tất cả components
- **Bao gồm:**
  - single_core (Core A, CORE_ID=0)
  - core_b (Core B, CORE_ID=1)
  - ace_interconnect (Cache Coherency)
- **Output:** L3 interface để kết nối với L3 Cache

## Cách sử dụng

### Compile với iverilog:
```bash
cd c:\Law\ISS-RV32ICMFA\Verilog\pipeline
iverilog -o dual_core.vvp \
    Core_B/soc_dual_core.v \
    Core_B/core_b.v \
    Bus_wrapper/single_core.v \
    dual_core/ace_interconect.v \
    RV32ICMFA/*.v \
    Cache/*.v \
    Bus_wrapper/arbiter.v \
    [testbench.v]
```

### Kết nối với L3 Cache:
```verilog
soc_dual_core u_soc (
    .ACLK       (clk),
    .ARESETn    (rst_n),
    
    // Kết nối với L3 Cache
    .m_l3_araddr    (l3_araddr),
    .m_l3_arvalid   (l3_arvalid),
    .m_l3_arready   (l3_arready),
    
    .m_l3_rdata     (l3_rdata),
    .m_l3_rvalid    (l3_rvalid),
    .m_l3_rlast     (l3_rlast),
    .m_l3_rready    (l3_rready)
);
```

## Ghi chú cho bạn của bạn

- **Core B giống hệt Core A**, chỉ khác `CORE_ID = 1`
- **Transaction ID** sẽ có bit cuối = 1 để phân biệt request từ Core nào
- **ACE Snoop** tự động hoạt động qua ace_interconnect
- **L3 interface** đã expose ra ngoài, chỉ cần kết nối với L3 Cache
