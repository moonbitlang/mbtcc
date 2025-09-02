
#include "test.h"

int matrix_add(int res[3][3], int mat1[3][3], int mat2[3][3]) {
  for (int i = 0; i < 3; i++) {
    for (int j = 0; j < 3; j++) {
      res[i][j] = mat1[i][j] + mat2[i][j];
    }
  }
  return 0;
}

int main() {
  int mat1[3][3] = {{1, 4, 3}, {0, 2, 6}, {7, 8, -3}};
  int mat2[3][3] = {{7, 3, 2}, {6, -1, 4}, {-3, 2, 1}};

  int res[3][3];

  matrix_add(res, mat1, mat2);
  for (int i = 0; i < 3; i++) {
    for (int j = 0; j < 3; j++) {
      printf("%d ", res[i][j]);
    }
    printf("\n");
  }
  return 0;
}
