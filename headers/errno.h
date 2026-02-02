#ifndef MBTCC_ERRNO_H
#define MBTCC_ERRNO_H

extern int errno;

#define EPERM 1
#define ENOENT 2
#define EIO 5
#define ENXIO 6
#define E2BIG 7
#define ENOEXEC 8
#define EBADF 9
#define ECHILD 10
#define EAGAIN 11
#define ENOMEM 12
#define EACCES 13
#define EFAULT 14
#define EBUSY 16
#define EEXIST 17
#define ENOTDIR 20
#define EISDIR 21
#define EINVAL 22
#define ETIMEDOUT 60
#define EDEADLK 11
#define ENFILE 23
#define EMFILE 24
#define ENOSPC 28
#define ENOLCK 77
#define ESPIPE 29
#define EROFS 30
#define EMLINK 31
#define EPIPE 32
#define EDOM 33
#define ERANGE 34
#define EINTR 4
#define ENOTSUP 45
#define EOPNOTSUPP 102
#define ENOTCONN 57
#define ENODEV 19
#define ENOSYS 78

#endif
