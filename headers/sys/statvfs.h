#ifndef MBTCC_SYS_STATVFS_H
#define MBTCC_SYS_STATVFS_H

struct statvfs {
  unsigned long f_bsize;
};

int fstatvfs(int fd, struct statvfs *buf);

#endif
