#include <stdlib.h>

int var = 0;

int g ()
{
  var = 1;
}

int f ()
{
  int f2 = 0;

  if (f2 == 0)
    ;

  g ();
}

int main ()
{
  f ();
  if (var != 1)
    abort ();
  exit (0);
}
