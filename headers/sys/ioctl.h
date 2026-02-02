#ifndef MBTCC_SYS_IOCTL_H
#define MBTCC_SYS_IOCTL_H

int ioctl(int fd, unsigned long request, ...);
int fsctl(const char *path, unsigned long request, void *data, unsigned int flags);

#define FIONREAD 0x541B
#define _IOWR(x,y,t) 0

#endif
