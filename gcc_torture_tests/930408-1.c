#include <stdlib.h>

typedef enum foo E;
enum foo { e0, e1 };

struct {
  E eval;
} s;

int p ()
{
  abort();
}

int f ()
{
  switch (s.eval)
    {
    case e0:
      p();
    }
}

int main ()
{
  s.eval = e1;
  f();
  exit(0);
}
