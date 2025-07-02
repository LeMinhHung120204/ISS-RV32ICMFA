class PHT:
    def __init__(self, size=1024):
        # Khởi tạo bảng PHT gồm nhiều bộ đếm 2-bit (giá trị từ 0 đến 3)
        self.size = size
        self.PHT = [1] * size  # Khởi đầu là '01' (weakly not taken)

    def predict(self, address):
        """Dự đoán nhánh từ địa chỉ (index vào bảng)"""
        index = address % self.size
        state = self.PHT[index]
        return state >= 2  # 10, 11 → taken; 00, 01 → not taken

    def update(self, address, taken):
        """Cập nhật trạng thái bộ đếm dựa trên kết quả thật sự"""
        # taken: True nếu nhánh được thực thi, False nếu không
        index = address % self.size
        if taken:
            self.PHT[index] = min(3, self.PHT[index] + 1)
        else:
            self.PHT[index] = max(0, self.PHT[index] - 1)

    def state_str(self, value):
        return [
            "Strongly Not Taken",
            "Weakly Not Taken",
            "Weakly Taken",
            "Strongly Taken"
        ][value]
