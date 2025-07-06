class GHR:
    def __init__(self, bits=8):
        self.bits = bits
        self.value = 0
        self.mask = (1 << bits) - 1  # tạo mặt nạ để giữ lại đúng số bit

    def update(self, taken: bool):
        self.value = ((self.value << 1) | int(taken)) & self.mask
        # Dịch trái và chèn bit taken vào LSB

    def read(self):
        return self.value
