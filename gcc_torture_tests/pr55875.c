#include <stdlib.h>

int a[251];
__attribute__ ((noinline))
int t (int i)
{
  if (i==0)
    exit(0);
  if (i>255)
    abort ();
}
int main ()
{
  unsigned int i;
  for (i=0;;i++)
    {
      a[i]=t((unsigned char)(i+5));
    }
}
