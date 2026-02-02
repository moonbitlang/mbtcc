#include <stdlib.h>

/* { dg-skip-if "requires alloca" { ! alloca } { "-O0" } { "" } } */
int g (int x, int y)
{
  if (x != 3)
    abort ();
}

static inline
int f (int i)
{
  int *tmp;

  tmp = (int *) alloca (sizeof (i));
  *tmp = i;
  g (*tmp, 0);
}

int main ()
{
  f (3);
  exit (0);
};
