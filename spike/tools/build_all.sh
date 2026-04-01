#!/usr/bin/env bash
set -euo pipefail

# Danh sách test muốn build lại
tests=(
  Verilog/test_case/test_case_bp1.s
  Verilog/test_case/test_case_bp2.s
  Verilog/test_case/test_case_bp3.s
  Verilog/test_case/test_case_bp4.s
  Verilog/test_case/test_case_bp5.s
  Verilog/test_case/test_case_bp6.s
  Verilog/test_case/test_case2.s

  # Các test dưới đây có thể trap/khó chấm PASS/FAIL trên Spike,
  # nhưng vẫn build được để chạy thử:
  Verilog/test_case/test_case1.s
  Verilog/test_case/test_case3.s
  Verilog/test_case/test_case_atomic.s
  Verilog/test_case/test_dualcore.s
  Verilog/test_case/test_soc.s
)

for t in "${tests[@]}"; do
  echo "==> Building: $t"
  Verilog/spike/tools/build_one.sh "$t"
done

echo ""
echo "Built all tests."
