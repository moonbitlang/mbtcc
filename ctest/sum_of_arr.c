#include "test.h"

int sum(int* arr, int len) {
  int total = 0;
  for (int i = 0; i < len; i++) {
      total += arr[i];
  }
  return total;
}

int main() {
  int arr[5] = {1, 2, 3, 4, 5};
  int result = sum(arr, 5);
  printf("%d\n", result); // Should print 15
  return 0;
}
