
int main() {
  int arr[5];
  arr[0] = 1;
  arr[1] = 2;
  arr[2] = 3;
  arr[3] = 4;
  arr[4] = 5;

  int total = 0;
  for (int i = 0; i < 5; i++) {
    total += arr[i];
  }
  return total; // Should return 15
}
