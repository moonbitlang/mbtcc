#ifndef MBTCC_SYS_STAT_H
#define MBTCC_SYS_STAT_H

#include <sys/types.h>
#include <sys/time.h>

struct stat {
  dev_t st_dev;
  ino_t st_ino;
  mode_t st_mode;
  unsigned short st_nlink;
  uid_t st_uid;
  gid_t st_gid;
  off_t st_size;
  long st_blksize;
  struct timespec st_mtimespec;
};

int stat(const char *path, struct stat *buf);
int fstat(int fd, struct stat *buf);
int chmod(const char *path, mode_t mode);
int fchmod(int fd, mode_t mode);
int mkdir(const char *path, mode_t mode);

#define S_IFMT 0170000
#define S_IFDIR 0040000
#define S_IFREG 0100000

#define S_ISDIR(m) (((m) & S_IFMT) == S_IFDIR)
#define S_ISREG(m) (((m) & S_IFMT) == S_IFREG)

#define S_IRUSR 0400
#define S_IWUSR 0200
#define S_IXUSR 0100
#define S_IRGRP 0040
#define S_IWGRP 0020
#define S_IXGRP 0010
#define S_IROTH 0004
#define S_IWOTH 0002
#define S_IXOTH 0001

#endif
