void println_int(int);

int main() {
  int a = 0x40400000;
  float *p = (float *)&a;
  float v = *p;
  int v2 = (int)v;
  println_int(v2);
  return 0;
}