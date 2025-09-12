# radix4_division.py
from typing import Tuple
from math import ceil

def _trial_q(u: int, D: int) -> int:
    """
    Chọn q_trial ∈ {0,1,2,3} sao cho u - q*D gần 0 nhất nhưng không âm (restoring).
    Triển khai bằng cách ước lượng q ≈ floor(u / D), rồi kẹp 0..3 và hiệu chỉnh một bước.
    """
    if u <= 0:
        return 0
    # floor estimate
    q = u // D
    if q > 3: q = 3
    # chỉnh nếu q quá lớn
    while q > 0 and u - q*D < 0:
        q -= 1
    # chỉnh nếu q có thể tăng thêm
    while q < 3 and u - (q+1)*D >= 0:
        q += 1
    return q

def div_int_radix4(N: int, D: int) -> Tuple[int, int]:
    """
    Chia số nguyên (có dấu) theo semantics Python:
      Q = N // D,  R = N % D,  với N = Q*D + R và R cùng dấu với D.
    Thuật toán: restoring radix-4 (mỗi vòng quyết định 2 bit thương).
    """
    if D == 0:
        raise ZeroDivisionError("division by zero")
    if N == 0:
        return 0, 0

    sign_mixed = (N < 0) ^ (D < 0)
    N_abs, D_abs = abs(N), abs(D)

    # Số chữ số base-4 cần quét (mỗi chữ số ~ 2 bit)
    n_digits = ceil(N_abs.bit_length() / 2) if N_abs != 0 else 1

    R = 0                   # partial remainder (không âm trong restoring)
    Q = 0                   # thương không dấu đang tích lũy (base-4)

    # Duyệt từ chữ số base-4 cao nhất xuống thấp nhất
    for i in range(n_digits - 1, -1, -1):
        # "Bring down" 2 bit tiếp theo của N_abs
        bring = (N_abs >> (2*i)) & 0b11
        U = (R << 2) + bring   # u = 4*R + bring

        # Chọn q_trial ∈ {0,1,2,3}
        q = _trial_q(U, D_abs)

        # Cập nhật R và Q
        R = U - q * D_abs
        Q = (Q << 2) | q

    # Bây giờ Q,R là kết quả cho phép chia không dấu theo "trunc toward zero"
    Q_u, R_u = Q, R

    # Áp dấu theo semantics Python (floor-division)
    if sign_mixed:
        # trunc toward zero → floor (với khác dấu) cần lùi 1 đơn vị nếu còn dư
        if R_u != 0:
            Q_signed = -Q_u - 1
            R_signed = R_u - D_abs  # âm, cùng dấu với D (D đang âm sau khi gán dấu)
        else:
            Q_signed = -Q_u
            R_signed = 0
    else:
        Q_signed = Q_u
        R_signed = R_u

    # Đưa remainder về cùng dấu với D
    if D < 0:
        Q_signed = -Q_signed
        R_signed = -R_signed

    return Q_signed, R_signed


if __name__ == "__main__":
    # Một vài test nhanh
    tests = [(37,5),(37,-5),(-37,5),(-37,-5),(0,7),(123456789,1234),(5,7),(7,5)]
    for N, D in tests:
        q, r = div_int_radix4(N, D)
        print(f"N={N}, D={D} -> Q={q}, R={r} | Python: Q={N//D}, R={N%D}")

    # Fuzzer
    import random
    random.seed(0)
    for _ in range(50000):
        N = random.randint(-10**12, 10**12)
        D = random.randint(-10**6, 10**6) or 1
        q, r = div_int_radix4(N, D)
        if (q, r) != (N // D, N % D):
            print("Mismatch:", N, D, (q, r), (N // D, N % D))
            break
    else:
        print("Random test: OK (matches Python // and %)")
