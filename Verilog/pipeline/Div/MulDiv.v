// MulDiv.v — phiên bản “dễ đọc”, giữ nguyên thuật toán như mã gốc
module MulDiv(
  input         clock,
  input         reset,

  // Request
  output        io_req_ready,
  input         io_req_valid,
  input  [3:0]  io_req_bits_fn,
  input  [31:0] io_req_bits_in1,
  input  [31:0] io_req_bits_in2,
  input  [4:0]  io_req_bits_tag,
  input         io_kill,

  // Response
  input         io_resp_ready,
  output        io_resp_valid,
  output [31:0] io_resp_bits_data,
  output [4:0]  io_resp_bits_tag
);

  // ------------------------------------------------------------
  // 1) Thanh ghi trạng thái & dữ liệu
  // ------------------------------------------------------------
  // Đặt tên state rõ ràng để dễ đọc
  localparam ST_IDLE   = 3'd0;
  localparam ST_PREP   = 3'd1; // bước “chuẩn bị” khi có số âm (nhánh chia)
  localparam ST_MUL    = 3'd2; // vòng lặp nhân 8-bit/chu kỳ (4 chu kỳ)
  localparam ST_DIV    = 3'd3; // vòng lặp chia restoring 1-bit/chu kỳ (32 chu kỳ)
  localparam ST_NEG    = 3'd5; // đổi dấu kết quả nếu cần
  localparam ST_RESP_M = 3'd6; // trả kết quả cho nhánh nhân
  localparam ST_RESP   = 3'd7; // trả kết quả cho nhánh chia

  reg [2:0]  state;       // FSM
  reg [4:0]  req_tag;     // lưu tag để trả đúng lệnh
  reg [5:0]  count;       // bộ đếm chu kỳ (chuỗi lặp)
  reg        neg_out;     // có cần đổi dấu kết quả ở cuối không
  reg        isHi;        // lệnh yêu cầu lấy phần High của kết quả?
  reg        resHi;       // chọn phần High/Low thực tế khi trả
  reg [32:0] divisor;     // 33-bit: toán hạng B (ghép thêm bit dấu bên trên)
  reg [65:0] remainder;   // thanh ghi đa năng: tích lũy/“dư”/“thương” (tùy nhánh)

  // ------------------------------------------------------------
  // 2) Giải mã lệnh (giữ đúng mặt nạ so với code gốc)
  // ------------------------------------------------------------
  wire [3:0] _t_and4  = (io_req_bits_fn & 4'h4);
  wire [3:0] _t_and5  = (io_req_bits_fn & 4'h5);
  wire [3:0] _t_and2  = (io_req_bits_fn & 4'h2);
  wire [3:0] _t_and6  = (io_req_bits_fn & 4'h6);
  wire [3:0] _t_and1  = (io_req_bits_fn & 4'h1);

  // Là nhân khi (fn & 4) == 0
  wire cmdMul    = (_t_and4 == 4'h0);

  // Lấy phần High: (fn & 5) == 1  hoặc  (fn & 2) == 2
  wire cmdHi     = (_t_and5 == 4'h1) | (_t_and2 == 4'h2);

  // Có dấu phía trái/phải theo “decode” của bản gốc
  wire lhsSigned = (_t_and6 == 4'h0) | (_t_and1 == 4'h0);
  wire rhsSigned = (_t_and6 == 4'h0) | (_t_and5 == 4'h4);

  // Bit dấu input (nếu là toán có dấu)
  wire lhs_sign = lhsSigned & io_req_bits_in1[31];
  wire rhs_sign = rhsSigned & io_req_bits_in2[31];

  // Định dạng đầu vào
  wire [31:0] lhs_in     = io_req_bits_in1;                 // A
  wire [32:0] divisor_in = {rhs_sign, io_req_bits_in2};     // {signB, B}  (33-bit)

  // ------------------------------------------------------------
  // 3) Handshake
  // ------------------------------------------------------------
  wire take_req   = io_req_ready & io_req_valid;            // nhận yêu cầu
  wire give_resp  = io_resp_ready & io_resp_valid;          // trả kết quả xong

  assign io_req_ready  = (state == ST_IDLE);
  assign io_resp_valid = (state == ST_RESP_M) | (state == ST_RESP);
  assign io_resp_bits_tag  = req_tag;

  // ------------------------------------------------------------
  // 4) Kết quả (chọn High/Low từ remainder)
  //     - High: remainder[64:33]
  //     - Low : remainder[31:0]
  // ------------------------------------------------------------
  wire [31:0] result_hi = remainder[64:33];
  wire [31:0] result_lo = remainder[31:0];
  wire [31:0] result    = resHi ? result_hi : result_lo;
  wire [31:0] neg_result = (~result) + 32'd1; // -result, tránh dùng toán tử “-” nếu bạn muốn thuần cổng

  assign io_resp_bits_data = result;

  // ------------------------------------------------------------
  // 5) Datapath CHIA (restoring 1-bit/chu kỳ)
  //    subtractor = (remainder_high 33b) - divisor (33b)
  //    Nếu không âm → nhận trừ & bit thương=1; Nếu âm → không trừ & bit thương=0
  // ------------------------------------------------------------
  wire [32:0] rem_high_33 = remainder[64:32];
  wire [32:0] subtractor  = rem_high_33 - divisor;          // 33-bit signed
  wire        less_than_0 = subtractor[32];                 // bit dấu

  wire [31:0] new_high32  = less_than_0 ? remainder[63:32]  // không trừ
                                        : subtractor[31:0]; // trừ được
  wire        qbit        = ~less_than_0;                   // bit thương sinh ra

  // Gói lại: {new_high32, old_low32, qbit}
  wire [64:0] unroll_pack = { new_high32, remainder[31:0], qbit };

  // div-by-zero detection ở vòng đầu (giữ cách làm của bản gốc):
  // Ở mã gốc: divby0 = (count==0) & (~less_than_0) — giữ nguyên ý tưởng phát hiện sớm
  wire divby0 = (count == 6'd0) & (~less_than_0);

  // ------------------------------------------------------------
  // 6) Datapath NHÂN (8-bit/chu kỳ)
  //    Lấy 9-bit signed: {mplierSign, mplier[7:0]} * divisor (33b signed) → 42b
  //    Cộng vào accum (33b, sign-extend lên 42b), rồi dịch lấy byte tiếp theo
  // ------------------------------------------------------------
  // Tách “mulReg” giống mã gốc: {remainder[65:33], remainder[31:0]}
  wire [64:0] mulReg      = { remainder[65:33], remainder[31:0] };
  wire        mplierSign  =  remainder[32];                  // “bit sign của byte” hiện tại
  wire [31:0] mplier      =  mulReg[31:0];                   // phần số nhân còn lại
  wire [32:0] accum_33    =  mulReg[64:32];                  // tích lũy 33-bit

  // 9-bit có dấu: {mplierSign, mplier[7:0]}
  wire [8:0]  pp9_signed  = { mplierSign, mplier[7:0] };

  // Nhân signed: (9b x 33b) = 42b
  wire signed [41:0] prod42  = $signed(pp9_signed) * $signed(divisor);

  // Cộng accum (sign-extend 33b → 42b)
  wire signed [41:0] accum42 = {{9{accum_33[32]}}, accum_33};
  wire signed [41:0] sum42   = prod42 + accum42;

  // Ghép lại: {sum42, mplier[31:8]} → 65-bit
  wire [64:0] nextMulReg     = { sum42, mplier[31:8] };

  // Ở mã gốc có “nextMplierSign = (count==2) & neg_out;”
  // (điều chỉnh sign bit khi chuyển sang byte cuối)
  wire nextMplierSign = (count == 6'd2) & neg_out;

  // Gói lại y như mã gốc (Cat hai lần để trùng bít)
  wire [64:0] nextMulReg1    = { nextMulReg[64:32], nextMulReg[31:0] };
  wire [65:0] remainder_mulN = { nextMulReg1[64:32], nextMplierSign, nextMulReg1[31:0] };

  // ------------------------------------------------------------
  // 7) FSM
  // ------------------------------------------------------------
  always @(posedge clock) begin
    if (reset) begin
      state    <= ST_IDLE;
      count    <= 6'd0;
      req_tag  <= 5'd0;
      neg_out  <= 1'b0;
      isHi     <= 1'b0;
      resHi    <= 1'b0;
      divisor  <= 33'd0;
      remainder<= 66'd0;
    end else begin
      // ---------- Quay về IDLE khi trả xong hoặc bị kill ----------
      if (give_resp | io_kill) begin
        state <= ST_IDLE;
      end

      // ---------- Nhận yêu cầu mới ----------
      if (take_req) begin
        req_tag   <= io_req_bits_tag;
        count     <= 6'd0;
        divisor   <= divisor_in;            // {rhs_sign, in2}
        remainder <= {34'd0, lhs_in};       // clear trên, nạp A vào dưới

        isHi      <= cmdHi;
        resHi     <= 1'b0;
        neg_out   <= cmdHi ? lhs_sign : (lhs_sign ^ rhs_sign);

        if (cmdMul) begin
          state <= ST_MUL;
        end else if (lhs_sign | rhs_sign) begin
          state <= ST_PREP;                 // có dấu → bước chuẩn bị
        end else begin
          state <= ST_DIV;                  // chia không dấu
        end
      end

      // ---------- PREP (bước chuẩn bị cho nhánh chia có dấu) ----------
      // Giữ đúng ý bản gốc:
      // - Nếu remainder[31]==1, thay remainder = {0…0, -result_lo}
      // - Nếu divisor[31]==1, cập nhật divisor = (remainder_high - divisor)
      if (state == ST_PREP) begin
        // result_lo = remainder[31:0]
        if (remainder[31]) begin
          // remainder <= {34'd0, -result_lo}
          remainder <= {34'd0, (~remainder[31:0]) + 32'd1};
        end
        // subtractor = remainder[64:32] - divisor (đã khai báo ở trên)
        if (divisor[31]) begin
          divisor <= subtractor; // theo code gốc
        end
        // Sang vòng chia
        state <= ST_DIV;
      end

      // ---------- NHÂN: 8-bit / chu kỳ (4 chu kỳ) ----------
      if (state == ST_MUL) begin
        // Cập nhật remainder theo datapath nhân
        remainder <= remainder_mulN;

        // Tăng count
        count <= count + 6'd1;

        // Khi đã xử lý đủ 4 byte (count==3) → kết thúc
        if (count == 6'd3) begin
          resHi <= isHi;        // chốt chọn phần Hi/Lo
          state <= ST_RESP_M;   // trả kết quả nhánh nhân
        end
      end

      // ---------- CHIA: restoring 1-bit / chu kỳ (32 chu kỳ) ----------
      if (state == ST_DIV) begin
        // Gói “unroll” 1 bước: {new_high32, old_low32, qbit}
        remainder <= {1'b0, unroll_pack}; // giữ MSB 0 giống mã gốc

        // Nếu phát hiện chia 0 ở bước đầu → chuẩn hoá neg_out (theo code gốc)
        if (divby0 && !isHi) begin
          neg_out <= 1'b0;
        end

        // Tăng count
        count <= count + 6'd1;

        // Sau 32 bước: chọn NEG (nếu cần) hoặc RESP
        if (count == 6'd32) begin
          resHi <= isHi;                     // chốt chọn phần Hi/Lo
          state <= (neg_out ? ST_NEG : ST_RESP);
        end
      end

      // ---------- ĐỔI DẤU KẾT QUẢ (nếu cần) ----------
      if (state == ST_NEG) begin
        remainder <= {34'd0, neg_result};    // chỉ đổi phần 32-bit trả ra
        state     <= ST_RESP;
      end
    end
  end

endmodule
