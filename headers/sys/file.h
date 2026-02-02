#ifndef MBTCC_SYS_FILE_H
#define MBTCC_SYS_FILE_H

int flock(int fd, int operation);

#define LOCK_SH 1
#define LOCK_EX 2
#define LOCK_NB 4
#define LOCK_UN 8

#endif
