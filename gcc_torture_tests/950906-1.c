#include <stdlib.h>

int g (int i)
{
}

int f (int i)
{
  g (0);
  while ( ({ i--; }) )
    g (0);
}

int main ()
{
  f (10);
  exit (0);
}
