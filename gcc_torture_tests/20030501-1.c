#include <stdlib.h>

static int retframe_block(int size)
{
  return size + 5;
}

int
main (int argc, char **argv)
{
  int size = 10;

  if (retframe_block(size) != 15)
    abort ();
  exit (0);
}
