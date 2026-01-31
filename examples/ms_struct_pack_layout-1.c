extern void abort ();

#ifndef MBTCC_SKIP_MS_STRUCT
#define MBTCC_SKIP_MS_STRUCT 1
#endif

union u
{
  int a;
} __attribute__((__ms_struct__, __packed__));

struct s
{
  char c;
  union u u;
};

int main (void)
{
#if MBTCC_SKIP_MS_STRUCT
  return 0;
#endif
  if (sizeof (struct s) != (sizeof (char) + sizeof (union u))) 
    abort ();

  return 0;
}
