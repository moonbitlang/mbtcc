#include <stdlib.h>
#include <stdio.h>

char buf[10];

extern void abort (void);
int main()
{
  int l = sprintf (buf, "foo\0bar");
  if (l != 3)
    abort ();
  return 0;
}
