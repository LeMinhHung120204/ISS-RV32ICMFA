#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <path-to-testcase.s|.S>"
  exit 1
fi

S="$1"
if [[ ! -f "$S" ]]; then
  echo "Error: file not found: $S"
  exit 1
fi

NAME="$(basename "$S")"
NAME="${NAME%.s}"
NAME="${NAME%.S}"

ABS="$(readlink -f "$S")"

WRAP="Verilog/spike/wrap/${NAME}.S"
ELF="Verilog/spike/elf/${NAME}.elf"
HEX="Verilog/spike/hex/${NAME}.hex"
BIN="Verilog/spike/build/${NAME}.bin"
LD="Verilog/spike/link.ld"

mkdir -p Verilog/spike/wrap Verilog/spike/elf Verilog/spike/hex Verilog/spike/build

cat > "$WRAP" <<EOF2
    .section .text
    .globl _start
_start:
    .include "${ABS}"
EOF2

riscv64-unknown-elf-gcc -nostdlib -nostartfiles \
  -march=rv32ia -mabi=ilp32 \
  -T "$LD" \
  -o "$ELF" "$WRAP"

riscv64-unknown-elf-objcopy -O ihex   "$ELF" "$HEX"
riscv64-unknown-elf-objcopy -O binary "$ELF" "$BIN"

echo "Built:"
echo "  ELF : $ELF"
echo "  HEX : $HEX"
echo "  BIN : $BIN"
echo "  WRAP: $WRAP"
