int main() {
  volatile unsigned int *p = (unsigned int *)0x80000000;
  p[0] = 0x11223344;
  p[1] = 0xAABBCCDD;
  while (1) { }
  return 0;
}
