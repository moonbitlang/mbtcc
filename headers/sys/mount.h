#ifndef MBTCC_SYS_MOUNT_H
#define MBTCC_SYS_MOUNT_H

struct statfs {
  unsigned int f_flags;
  int f_bsize;
  char f_fstypename[16];
};

int statfs(const char *path, struct statfs *buf);
int fstatfs(int fd, struct statfs *buf);

#define MNT_RDONLY 0x0001
#define MNT_LOCAL  0x0002
#define MFSNAMELEN 16

#endif
