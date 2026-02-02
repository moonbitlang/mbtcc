#include <stdlib.h>

int
f (int b)
{
  return (b >> 1) > 0;
}

int main ()
{
  if (!f (9))
    abort ();
  if (f (-9))
    abort ();
  exit (0);
}
