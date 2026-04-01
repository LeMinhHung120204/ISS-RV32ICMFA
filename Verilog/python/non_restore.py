# non_restoring_division_fixed.py
from typing import Tuple

def _nonrestoring_core_unsigned(N_abs: int, D_abs: int) -> Tuple[int, int]:
    assert D_abs > 0
    R = 0
    Q = 0
    # Duyệt từ MSB -> LSB của N_abs
    for i in range(N_abs.bit_length() - 1, -1, -1):
        # 1) Dịch trái R và nạp bit i của N
        R = (R << 1) | ((N_abs >> i) & 1)

        # 2) Non-restoring cập nhật R
        if R >= 0:
            R = R - D_abs
        else:
            R = R + D_abs

        # 3) Gán bit thương THEO DẤU MỚI CỦA R
        if R >= 0:
            Q = (Q << 1) | 1
        else:
            Q = (Q << 1) | 0

    # 4) Chuẩn hóa dư dương
    if R < 0:
        R += D_abs

    return Q, R

def div_int_nonrestoring(N: int, D: int) -> Tuple[int, int]:
    if D == 0:
        raise ZeroDivisionError("division by zero")
    if N == 0:
        return 0, 0

    N_abs, D_abs = abs(N), abs(D)
    Q_u, R_u = _nonrestoring_core_unsigned(N_abs, D_abs)

    # chuyển sang có dấu theo trunc-toward-zero
    mixed = (N < 0) ^ (D < 0)
    Q_tz = -Q_u if mixed else Q_u
    R0   = -R_u if (N < 0) else R_u

    # điều chỉnh về semantics của Python (floor-division)
    if R0 != 0 and mixed:
        Q = Q_tz - 1
        R = R0 + D
    else:
        Q = Q_tz
        R = R0
    return Q, R

if __name__ == "__main__":
    tests = [(37,5),(37,-5),(-37,5),(-37,-5),(0,7),(123456789,1234),(5,7),(7,5)]
    for N,D in tests:
        q,r = div_int_nonrestoring(N,D)
        print(f"N={N}, D={D}  ->  Q={q}, R={r} | Python: Q={N//D}, R={N%D}")

    import random
    random.seed(0)
    for _ in range(50000):
        N = random.randint(-10**12, 10**12)
        D = random.randint(-10**6, 10**6) or 1
        if (q:=div_int_nonrestoring(N,D)) != (N//D, N%D):
            print("Mismatch:", N, D, q, (N//D, N%D))
            break
    else:
        print("Random test: OK (matches Python // and %)")
