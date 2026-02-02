#ifndef MBTCC_PWD_H
#define MBTCC_PWD_H

#include <sys/types.h>

struct passwd {
  char *pw_dir;
};

struct passwd *getpwuid(uid_t);

#endif
