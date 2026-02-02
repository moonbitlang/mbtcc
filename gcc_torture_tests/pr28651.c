#include <limits.h>
#include <stdlib.h>

extern void abort (void);
__attribute__((noinline))
int foo (unsigned int u)
{
  return (int)(u + 4) < (int)u;
}

int
main (int argc, char *argv[])
{
  unsigned int u = INT_MAX;

  if (foo (u) == 0)
    abort();
  return 0;
}
