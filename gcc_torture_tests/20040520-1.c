#include <stdlib.h>

/* PR 15454 */

void abort ();
static int g_foo;

static int bar (void)
{
  int baz = 0;
  if (g_foo != 45)
    baz = g_foo;
  return baz;
}

int main () {
        g_foo = 1;
        if (!bar ())
                abort ();
        return 0;
}
