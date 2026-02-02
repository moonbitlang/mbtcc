#ifndef MBTCC_SYS_RESOURCE_H
#define MBTCC_SYS_RESOURCE_H

#include <sys/time.h>

struct rusage {
  struct timeval ru_utime;
  struct timeval ru_stime;
};

int getrusage(int, struct rusage *);

#define RUSAGE_SELF 0

#endif
