#ifndef MBTCC_SYS_SYSCTL_H
#define MBTCC_SYS_SYSCTL_H

#include <sys/types.h>

int sysctlbyname(const char *name, void *oldp, size_t *oldlenp, void *newp, size_t newlen);

#endif
