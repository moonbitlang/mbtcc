
#include "test.h"

int main() {
  int arr2d[2][2] = {{1, 2}, {3, 4}};

  int sum = 0;
  for (int i = 0; i < 2; i++) {
    for (int j = 0; j < 2; j++) {
      sum += arr2d[i][j];
    }
  }
  printf("%d\n", sum);
  return 0; // Expected return value is 10
}
