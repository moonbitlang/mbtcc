#include <stdlib.h>

extern void abort (void);

int test(int n)
{
  n++;
  return n;
}

int main()
{
  if (test(123) != 123)
    abort ();
  return 0;
}
