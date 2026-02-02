#include <stdlib.h>

extern void abort(void);

__attribute__((noinline))
int foo (int bits_per_pixel, int depth)
{
  if ((bits_per_pixel | depth) == 1)
    abort ();
  return bits_per_pixel;
}

int main()
{
  if (foo(2, 0) != 2)
    abort ();
  return 0;
}
