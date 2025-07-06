class BTBEntry:
    def __init__(self, tag, target):
        self.tag = tag          # Bit cao của PC (25 bit)
        self.target = target    # Địa chỉ đích nhảy tới (PC predict)

class BTB:
    def __init__(self, size=32):
        self.size = size  # Số dòng BTB
        self.entries = [None] * size  # Khởi tạo rỗng

    def _get_index_tag(self, pc):
        index = (pc >> 2) & (self.size - 1)  # lấy 5 bit giữa: PC[6:2]
        tag = pc >> (2 + 5)     # lấy 25 bit cao: PC[31:7]
        return index, tag

    def lookup(self, pc):
        index, tag = self._get_index_tag(pc)
        entry = self.entries[index]

        if entry and entry.tag == tag:
            return True, entry.target     # hit
        else:
            return False, None            # miss

    def update(self, pc, target):
        index, tag = self._get_index_tag(pc)
        self.entries[index] = BTBEntry(tag, target)