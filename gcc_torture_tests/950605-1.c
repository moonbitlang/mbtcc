#include <stdlib.h>

int f (c)
    unsigned char c;
{
  if (c != 0xFF)
    abort ();
}

int main ()
{
  f (-1);
  exit (0);
}
