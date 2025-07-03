from core.bru import BRU

test_branches = [
    # CASE A: PHT Taken, BTB Hit → đúng
    {"pc": 0x100, "taken": True,  "target": 0x200},

    # CASE B: PHT Taken, BTB Miss → fallback
    {"pc": 0x104, "taken": True,  "target": 0x300},

    # CASE C: PHT Not Taken → đúng
    {"pc": 0x108, "taken": False, "target": 0x10C},

    # CASE D: PHT Not Taken nhưng nhánh thật sự Taken → sai
    {"pc": 0x10C, "taken": True,  "target": 0x208},
]

def test_predictor():
    bru = BRU(ghr_bits=4, pht_size=16, btb_size=4)

    correct_dir = 0
    correct_target = 0
    total = 0

    for epoch in range(2):
        print(f"\n=== Epoch {epoch + 1} ===")
        for i, branch in enumerate(test_branches):
            pc = branch["pc"]
            taken = branch["taken"]
            target = branch["target"]

            # 1. Dự đoán như IF stage
            pred_taken, pred_target = bru.predict(pc)

            # 2. Lấy thông tin debug
            ghr_val = bru.ghr.read()
            index = (pc >> 2) ^ ghr_val
            index %= bru.pht.size
            pht_val = bru.pht.table[index]
            real_target = target if taken else pc + 4

            # 3. Đánh giá kết quả
            is_dir_correct = pred_taken == taken
            is_addr_correct = pred_target == real_target

            correct_dir += is_dir_correct
            correct_target += is_addr_correct
            total += 1

            print(f"[{i}] PC={pc:#05x} | Taken={taken} | GHR={ghr_val:04b} | "
                  f"Index={index:02} | PHT={pht_val} | "
                  f"Predicted: {pred_taken}, Target: {pred_target:#05x} | "
                  f"{'correct' if is_dir_correct else 'wrong'} Dir | "
                  f"{'correct' if is_addr_correct else 'wrong'} Addr")

            # 4. Sau khi lệnh thực thi → update predictor
            bru.update(pc, taken, target)

    print(f"\nAccuracy Direction: {correct_dir}/{total} = {correct_dir/total:.2%}")
    print(f"Accuracy Address  : {correct_target}/{total} = {correct_target/total:.2%}")

if __name__ == "__main__":
    test_predictor()
