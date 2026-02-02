#include <stdio.h>
#include <stdlib.h>
int g ()
{
  return '\n';
}

int f ()
{
  char s[] = "abcedfg012345";
  char *sp = s + 12;

  switch (g ())
    {
      case '\n':
        break;
    }

  while (*--sp == '0')
    ;
  sprintf (sp + 1, "X");

  if (s[12] != 'X')
    abort ();
}

int main ()
{
  f ();
  exit (0);
}
