#include <stdlib.h>

struct a
{
  unsigned int bitfield : 3;
};

int foo (unsigned int z);

int main()
{
  struct a a;

  a.bitfield = 131;
  foo (a.bitfield);
  exit (0);
}

int foo (unsigned int z)
{
  if (z != 3)
    abort ();
  return 0;
}
