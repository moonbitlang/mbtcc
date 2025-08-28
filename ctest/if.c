
int max(int a, int b) {
  int res;
  if (a > b) {
    res = a;
  } else {
    res = b;
  }
  return res;
}

int main () {
  int res = max(3, 5);
  return res;
}
