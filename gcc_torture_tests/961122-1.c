#include <stdlib.h>

long long acc;

int addhi (short a)
{
  acc += (long long) a << 32;
}

int subhi (short a)
{
  acc -= (long long) a << 32;
}

int main ()
{
  acc = 0xffff00000000ll;
  addhi (1);
  if (acc != 0x1000000000000ll)
    abort ();
  subhi (1);
  if (acc != 0xffff00000000ll)
    abort ();
  exit (0);
}
