#!/usr/bin/env bash
set -euo pipefail

for elf in Verilog/spike/elf/*.elf; do
  name=$(basename "$elf")
  echo "===== $name ====="
  riscv64-unknown-elf-nm -n "$elf" | egrep '(_start|done|exit)$' || echo "(no _start/done/exit symbol)"
  echo ""
done
