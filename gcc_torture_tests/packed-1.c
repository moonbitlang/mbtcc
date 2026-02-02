#include <stdlib.h>

short x1 = 17;

struct
{
  short i __attribute__ ((packed));
} t;

int f ()
{
  t.i = x1;
  if (t.i != 17)
    abort ();
}

int main ()
{
  f ();
  exit (0);
}
