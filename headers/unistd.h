#ifndef MBTCC_UNISTD_H
#define MBTCC_UNISTD_H

#include <sys/types.h>

int access(const char *, int);
uid_t getuid(void);
uid_t geteuid(void);
pid_t getpid(void);
int isatty(int);
int close(int fd);
ssize_t read(int fd, void *buf, size_t count);
ssize_t write(int fd, const void *buf, size_t count);
off_t lseek(int fd, off_t offset, int whence);
int fsync(int fd);
int ftruncate(int fd, off_t length);
int unlink(const char *path);
int rmdir(const char *path);
int fchown(int fd, uid_t owner, gid_t group);
char *getcwd(char *buf, size_t size);
int usleep(unsigned int usec);
unsigned int sleep(unsigned int seconds);
ssize_t pread(int fd, void *buf, size_t count, off_t offset);
ssize_t pwrite(int fd, const void *buf, size_t count, off_t offset);
long sysconf(int name);

#define _SC_PAGESIZE 29

#define F_OK 0
#define X_OK 1
#define W_OK 2
#define R_OK 4

#endif
