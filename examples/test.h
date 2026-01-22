
int printf(const char *format, ...);
int sprintf(char *buf, const char *format, ...);

double sqrt(double x);

float sqrtf(float x);

void* malloc(unsigned long);

void free(void* ptr);

void exit(int status);

int strcmp(const char *s1, const char *s2);
int strncmp(const char *s1, const char *s2, unsigned long n);

void assert(int expected, int actual, char *code) {
  if (expected == actual) {
    printf("%s => %d\n", code, actual);
  } else {
    printf("%s => %d expected but got %d\n", code, expected, actual);
    exit(1);
  }
}

#define ASSERT(x, y) assert(x, y, #y)
