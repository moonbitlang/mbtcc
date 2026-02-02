#include <stdlib.h>

/* { dg-options "-fgnu89-inline" } */

extern void abort (void);
extern void exit (int);

double d;

static inline double foo (void)
{
  return d;
}

static inline int bar (void)
{
  foo();
  return 0;
}

int main (void)
{
  if (bar ())
    abort ();
  exit (0);
}
