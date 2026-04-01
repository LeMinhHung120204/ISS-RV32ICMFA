int main() {
  volatile unsigned int *p = (unsigned int *)0x80000000;
  p[0] = 0x11223344;
  p[1] = 0xAABBCCDD;

  // === PHẦN QUAN TRỌNG: Báo Spike kết thúc test thành công ===
  volatile unsigned int *tohost = (unsigned int *)0x80001000;
  *tohost = 1;        // Viết 1 = PASS (Spike sẽ tự dừng)

  while (1);          // vẫn giữ để an toàn
  return 0;
}
