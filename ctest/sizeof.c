
#include "test.h"

typedef struct { int a; char b; } S1;
typedef struct { int a; char b; char c; } S2;
typedef struct { int a; char b; char c; char d; } S3;
typedef struct { int a; char b; char c; char d; char e; } S4;
typedef struct { int a; double b; } S5;
typedef struct { double a; int b; } S6;
typedef struct { S1 a; int b; } S7;



int is_eq(int a, int b) {
  if (a == b) {
    return 1;
  }
  return 0;
}

int main() {
  int passed = 0;
  passed += is_eq(1, sizeof(char));
  passed += is_eq(2, sizeof(short));
  passed += is_eq(4, sizeof(int));
  passed += is_eq(4, sizeof(unsigned));
  passed += is_eq(4, sizeof(unsigned int));
  passed += is_eq(8, sizeof(long));
  passed += is_eq(8, sizeof(long long));
  passed += is_eq(8, sizeof(unsigned long));
  passed += is_eq(8, sizeof(unsigned long long));
  passed += is_eq(4, sizeof(float));
  passed += is_eq(8, sizeof(double));
  passed += is_eq(8, sizeof(void*));
  passed += is_eq(8, sizeof(S1));
  passed += is_eq(8, sizeof(S2));
  passed += is_eq(8, sizeof(S3));
  passed += is_eq(8, sizeof(S4));
  passed += is_eq(16, sizeof(S5));
  passed += is_eq(16, sizeof(S6));
  passed += is_eq(16, sizeof(S7));

  int arr[10];
  passed += is_eq(40, sizeof(arr));

  printf("%d\n", passed);
  return 0;
}
