
int sum(int n) {
    int s = 0;
    do {
        s += n;
        n--;
    } while (n > 0);
    return s;
}

int main() {
  return sum(10); // Expected: 55
}
