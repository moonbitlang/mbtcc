int val;

int *ptr = &val;
float *ptr2 = &val;

__attribute__ ((optimize ("-fno-strict-aliasing")))
int typepun ()
{
  *ptr2=0;
}

int main ()
{
  *ptr=1;
  typepun ();
  if (*ptr)
    __builtin_abort ();
}
