from pht import PHT
from btb import BTB
from ghr import GHR

class GshareBranchPredictor:
    def __init__(self, ghr_bits=8, pht_size=256, btb_size=32):
        self.ghr = GHR(bits=ghr_bits)
        self.pht = PHT(size=pht_size)
        self.btb = BTB(size=btb_size)

    def predict(self, pc):
        ghr_value = self.ghr.read()
        index = (pc >> 2) ^ ghr_value   # Gshare = PC xor GHR
        direction = self.pht.predict(index)  # Taken or Not Taken

        hit, target = self.btb.lookup(pc)
        if direction and hit:
            return True, target  # Taken → dùng target từ BTB
        else:
            return False, pc + 4  # Not taken → PC + 4

    def update(self, pc, taken, target):
        ghr_value = self.ghr.read()
        index = (pc >> 2) ^ ghr_value
        self.pht.update(index, taken)
        self.ghr.update(taken)
        self.btb.update(pc, target)
