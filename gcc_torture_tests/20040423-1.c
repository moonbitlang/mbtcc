#include <stdlib.h>
#include <string.h>

int
sub1 (int i, int j)
{
  size_t c_size = sizeof (int) * (i + 2);
  int x[10], y[10];

  if (j == 2)
    {
      memcpy (x, y, 10 * sizeof (int));
      return (int)c_size;
    }
  else
    return (int)(c_size * 3);
}

int
main ()
{
  size_t c_size = sizeof (int) * 22;
  if (sub1 (20, 3) != (int)(c_size * 3))
    abort ();

  return 0;
}
