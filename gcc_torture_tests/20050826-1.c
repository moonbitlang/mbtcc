#include <stdlib.h>
#include <string.h>

/* PR rtl-optimization/23561 */

struct A
{
  char a1[1];
  char a2[5];
  char a3[1];
  char a4[2048 - 7];
} a;

extern void abort (void);

void
bar (struct A *x)
{
  size_t i;
  if (memcmp (x, "\1HELLO\1", sizeof "\1HELLO\1"))
    abort ();
  for (i = 0; i < sizeof (x->a4); i++)
    if (x->a4[i])
      abort ();
}

int
foo (void)
{
  memset (&a, 0, sizeof (a));
  a.a1[0] = 1;
  memcpy (a.a2, "HELLO", sizeof "HELLO");
  a.a3[0] = 1;
  bar (&a);
  return 0;
}

int
main (void)
{
  foo ();
  return 0;
}
