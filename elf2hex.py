import sys
import struct
import subprocess
import os

if len(sys.argv) < 3:
    print("Usage: python elf2hex.py <input_elf> <output_hex>")
    sys.exit(1)

input_elf = sys.argv[1]
output_hex = sys.argv[2]
temp_bin = input_elf + ".bin"

# Chuyển ELF sang BIN bằng objcopy
objcopy_cmd = ["riscv64-unknown-elf-objcopy", "-O", "binary", input_elf, temp_bin]
try:
    subprocess.run(objcopy_cmd, check=True)
except Exception as e:
    print(f"Error running objcopy: {e}")
    sys.exit(1)

# Đọc BIN và ghi ra định dạng HEX (1 word 32-bit mỗi dòng)
with open(temp_bin, "rb") as f_in, open(output_hex, "w") as f_out:
    while True:
        chunk = f_in.read(4)
        if not chunk:
            break
        # Pad nếu chunk nhỏ hơn 4 bytes
        if len(chunk) < 4:
            chunk += b'\x00' * (4 - len(chunk))
        
        # Parse theo little endian
        val = struct.unpack("<I", chunk)[0]
        # Ghi ra định dạng hex 8 kí tự, giống với định dạng readmemh của Verilog
        f_out.write(f"{val:08x}\n")

# Xóa file bin tạm
os.remove(temp_bin)
print(f"Thành công: Đã tạo file {output_hex} từ {input_elf}!")
