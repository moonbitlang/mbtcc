/* { dg-additional-options "-Wl,-u,_printf_float" { target newlib_nano_io } } */

#include <stdio.h>
#include <stdlib.h>
char buf[2];

int f (fp)
     int (*fp)(char *, const char *, ...);
{
  (*fp)(buf, "%.0f", 5.0);
}

int main ()
{
  f (&sprintf);
  if (buf[0] != '5' || buf[1] != 0)
    abort ();
  exit (0);
}
