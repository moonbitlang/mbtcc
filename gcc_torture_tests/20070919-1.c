#include <stdlib.h>
#include <string.h>

/* PR c/33238 */
/* { dg-require-effective-target alloca } */

void abort (void);

struct S { char w[8]; };

void
__attribute__ ((noinline))
bar (void *x, void *y)
{
  struct S *p = x, *q = y;
  if (memcmp (p->w, "zyxwvut", 8) != 0)
    abort ();
  if (memcmp (q[0].w, "abcdefg", 8) != 0)
    abort ();
  if (memcmp (q[1].w, "ABCDEFG", 8) != 0)
    abort ();
  if (memcmp (q[2].w, "zyxwvut", 8) != 0)
    abort ();
  if (memcmp (q[3].w, "zyxwvut", 8) != 0)
    abort ();
}

void
__attribute__ ((noinline))
foo (void *x, int y)
{
  struct S *p = x, a;
  int i;
  a = p[2];
  p[3] = a;
  bar (&a, x);
}

int
main (void)
{
  struct S p[4] = { "abcdefg", "ABCDEFG", "zyxwvut", "ZYXWVUT" };
  foo (p, 8);
  return 0;
}
