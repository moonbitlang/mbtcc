
int deref(int* p) {
  return *p;
}

int main() {
  int x = 42;
  int* p = &x;
  int y = deref(p);
  return y;
}
