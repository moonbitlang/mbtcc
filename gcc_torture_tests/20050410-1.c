#include <stdlib.h>

int s = 200;
__attribute__((noinline))
int foo (void)
{
  return (signed char) (s - 100) - 5;
}
int
main (void)
{
  if (foo () != 95)
    abort ();
  exit (0);
}
