
int printf(const char *format, ...);

double sqrt(double x);

float sqrtf(float x);

void* malloc(unsigned long);

void free(void* ptr);

void exit(int status);

void assert(int expected, int actual, char *code) {
  if (expected == actual) {
    printf("%s => %d\n", code, actual);
  } else {
    printf("%s => %d expected but got %d\n", code, expected, actual);
    exit(1);
  }
}

#define ASSERT(x, y) assert(x, y, #y)
