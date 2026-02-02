#include <stdlib.h>

/* { dg-require-effective-target trampolines } */

int f0(int (*fn)(int *), int *p)
{
  return (*fn) (p);
}

static int *g_i;

static int f2(int *p)
{
  *g_i = 1;
  return *p + 1;
}

int f1(void)
{
  int i = 0;

  g_i = &i;
  return f0(f2, &i);
}

int main()
{
  if (f1() != 2)
    abort ();

  return 0;
}
