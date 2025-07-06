class ALU:
    def __init__(self):
        pass

    def execute(self, ALUControlE: int, SrcAE: int, SrcBE: int) -> int:
        """
        Mô phỏng hành vi ALU (ALUControlE)
        """
        shift_amt = SrcBE & 0x1F  # Chỉ lấy 5 bit thấp

        if ALUControlE == 0b00000:      # ADD
            return (SrcAE + SrcBE) & 0xFFFFFFFF
        elif ALUControlE == 0b00001:    # SUB
            return (SrcAE - SrcBE) & 0xFFFFFFFF
        elif ALUControlE == 0b00010:    # SLL
            return (SrcAE << shift_amt) & 0xFFFFFFFF
        elif ALUControlE == 0b00100:    # SLT (signed)
            return int(self._signed(SrcAE) < self._signed(SrcBE))
        elif ALUControlE == 0b01000:    # SLTU (unsigned)
            return int((SrcAE & 0xFFFFFFFF) < (SrcBE & 0xFFFFFFFF))
        elif ALUControlE == 0b10000:    # XOR
            return SrcAE ^ SrcBE
        elif ALUControlE == 0b10001:    # SRL
            return (SrcAE & 0xFFFFFFFF) >> shift_amt
        elif ALUControlE == 0b10010:    # SRA (signed)
            return self._sra(SrcAE, shift_amt)
        elif ALUControlE == 0b11000:    # OR
            return SrcAE | SrcBE
        elif ALUControlE == 0b11100:    # AND
            return SrcAE & SrcBE
        else:
            return (SrcAE + SrcBE) & 0xFFFFFFFF

    def branch(self, Bop: int, SrcAE: int, SrcBE: int) -> bool:
        """
        Mô phỏng điều kiện nhảy theo Bop (3-bit)
        """
        if Bop == 0b000:      # BEQ
            return SrcAE == SrcBE
        elif Bop == 0b001:    # BNE
            return SrcAE != SrcBE
        elif Bop == 0b100:    # BLT
            return self._signed(SrcAE) < self._signed(SrcBE)
        elif Bop == 0b101:    # BGE
            return self._signed(SrcAE) >= self._signed(SrcBE)
        elif Bop == 0b110:    # BLTU
            return SrcAE < SrcBE
        elif Bop == 0b111:    # BGEU
            return SrcAE >= SrcBE
        else:
            return False

    def _signed(self, val: int) -> int:
        """Chuyển int 32-bit thành số signed Python"""
        return val if val < 0x80000000 else val - 0x100000000

    def _sra(self, val: int, shamt: int) -> int:
        """Shift phải số học"""
        if val & 0x80000000:
            return ((val | (~0xFFFFFFFF)) >> shamt) & 0xFFFFFFFF
        else:
            return (val >> shamt) & 0xFFFFFFFF
