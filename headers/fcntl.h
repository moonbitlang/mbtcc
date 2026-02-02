#ifndef MBTCC_FCNTL_H
#define MBTCC_FCNTL_H

#include <sys/types.h>

struct flock {
  short l_type;
  short l_whence;
  off_t l_start;
  off_t l_len;
  pid_t l_pid;
};

int open(const char *path, int oflag, ...);
int fcntl(int fd, int cmd, ...);

#define O_RDONLY 0x0000
#define O_WRONLY 0x0001
#define O_RDWR   0x0002
#define O_CREAT  0x0200
#define O_EXCL   0x0800
#define O_TRUNC  0x0400
#define O_APPEND 0x0008
#define O_BINARY 0x0000

#define FD_CLOEXEC 1
#define O_CLOEXEC 0
#define O_NOFOLLOW 0

#define F_GETLK 7
#define F_SETLK 8
#define F_SETLKW 9
#define F_GETFD 1
#define F_SETFD 2

#define F_RDLCK 1
#define F_WRLCK 2
#define F_UNLCK 3

#endif
