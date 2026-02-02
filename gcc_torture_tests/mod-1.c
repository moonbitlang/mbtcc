#include <stdlib.h>

int f (int x, int y)
{
  if (x % y != 0)
    abort ();
}

int main ()
{
  f (-5, 5);
  exit (0);
}
