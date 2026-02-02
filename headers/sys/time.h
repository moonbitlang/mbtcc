#ifndef MBTCC_SYS_TIME_H
#define MBTCC_SYS_TIME_H

#include <sys/types.h>

struct timeval {
  long tv_sec;
  long tv_usec;
};

struct timespec {
  long tv_sec;
  long tv_nsec;
};

struct timezone {
  int tz_minuteswest;
  int tz_dsttime;
};

int gettimeofday(struct timeval *, void *);
int utimes(const char *path, const struct timeval times[2]);
int futimes(int fd, const struct timeval times[2]);

#endif
