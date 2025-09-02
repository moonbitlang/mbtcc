#include "test.h"

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
  // Should print 15
  printf("%d ", total);

  int arr2[5] = {1, 2, 3, 4, 5};

  int total2 = 0;
  for (int i = 0; i < 5; i++) {
    total2 += arr2[i];
  }
  printf("%d ", total2);

  int arr2d[2][2] = {{1, 2}, {3, 4}};

  int sum = 0;
  for (int i = 0; i < 2; i++) {
    for (int j = 0; j < 2; j++) {
      sum += arr2d[i][j];
    }
  }
  printf("%d ", sum);

  double a[5] = { 1.0, 3., 5, 7e+0, 9, };

  double sum2 = 0.0;
  for (int i = 0; i < 5; i++) {
    sum2 += a[i];
  }
  printf("%lf\n", sum2);
  return 0;
}
