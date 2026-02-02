#include <limits.h>
#include <stdlib.h>

int n = 0;

int g (int i)
{
  n++;
}

int f (int m)
{
  int i;
  i = m;
  do
    {
      g (i * 4);
      i -= INT_MAX / 8;
    }
  while (i > 0);
}

int main ()
{
  f (INT_MAX/8*4);
  if (n != 4)
    abort ();
  exit (0);
}
