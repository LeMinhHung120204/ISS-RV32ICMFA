class RegisterFile:
    # Ánh xạ tên ABI → chỉ số thanh ghi xN
    abi_map = {
        "zero": 0,  "ra": 1,   "sp": 2,   "gp": 3,
        "tp": 4,    "t0": 5,   "t1": 6,   "t2": 7,
        "s0": 8,    "fp": 8,   "s1": 9,
        "a0": 10,   "a1": 11,  "a2": 12,  "a3": 13,
        "a4": 14,   "a5": 15,  "a6": 16,  "a7": 17,
        "s2": 18,   "s3": 19,  "s4": 20,  "s5": 21,
        "s6": 22,   "s7": 23,  "s8": 24,  "s9": 25,
        "s10": 26,  "s11": 27,
        "t3": 28,   "t4": 29,  "t5": 30,  "t6": 31,
    }

    # Ánh xạ tên ABI float → chỉ số fN
    f_abi_map = {
        f"ft{i}": i for i in range(8)         # ft0–ft7 → f0–f7
    } | {
        f"fs{i}": i+8 for i in range(2)       # fs0–fs1 → f8–f9
    } | {
        f"fa{i}": i+10 for i in range(8)      # fa0–fa7 → f10–f17
    } | {
        f"fs{i}": i+18 for i in range(2, 12)  # fs2–fs11 → f18–f27
    } | {
        f"ft{i+8}": i+28 for i in range(4)    # ft8–ft11 → f28–f31
    }

    def __init__(self):
        self.x = [0] * 32       # Thanh ghi integer x0 - x31
        self.f = [0.0] * 32     # Thanh ghi float f0 - f31 (IEEE-754)
        self.pc = 0             # Program Counter
        self.fcsr = 0           # Float CSR: status flags, rounding mode, etc. (nếu cần)

    # --- Thanh ghi Integer ---

    def get_x_index(self, name_or_idx):
        if isinstance(name_or_idx, str):
            return self.abi_map[name_or_idx]
        return name_or_idx

    def read_x(self, idx) -> int:
        idx = self.get_x_index(idx)
        if idx == 0:
            return 0
        return self.x[idx]

    def write_x(self, idx, value: int):
        idx = self.get_x_index(idx)
        if idx != 0:
            self.x[idx] = value & 0xFFFFFFFF

    # --- Thanh ghi Float ---

    def get_f_index(self, name_or_idx):
        if isinstance(name_or_idx, str):
            return self.f_abi_map[name_or_idx]
        return name_or_idx

    def read_f(self, idx) -> float:
        idx = self.get_f_index(idx)
        return self.f[idx]

    def write_f(self, idx, value: float):
        idx = self.get_f_index(idx)
        self.f[idx] = float(value)  # đảm bảo IEEE-754 đơn

    # --- Debug ---

    def dump_x(self):
        print("=== Integer Registers ===")
        for i in range(0, 32, 4):
            print(f"x{i:02}: {self.read_x(i):08x}  "
                  f"x{i+1:02}: {self.read_x(i+1):08x}  "
                  f"x{i+2:02}: {self.read_x(i+2):08x}  "
                  f"x{i+3:02}: {self.read_x(i+3):08x}")
        print(f"PC: {self.pc:08x}")

    def dump_f(self):
        print("=== Floating-Point Registers ===")
        for i in range(0, 32, 4):
            print(f"f{i:02}: {self.read_f(i):.8e}  "
                  f"f{i+1:02}: {self.read_f(i+1):.8e}  "
                  f"f{i+2:02}: {self.read_f(i+2):.8e}  "
                  f"f{i+3:02}: {self.read_f(i+3):.8e}")