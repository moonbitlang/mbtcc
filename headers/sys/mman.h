#ifndef MBTCC_SYS_MMAN_H
#define MBTCC_SYS_MMAN_H

#include <sys/types.h>

void *mmap(void *addr, size_t len, int prot, int flags, int fd, off_t off);
int munmap(void *addr, size_t len);
void *mremap(void *old_address, size_t old_size, size_t new_size, int flags);

#define PROT_READ 0x1
#define PROT_WRITE 0x2

#define MAP_SHARED 0x01
#define MAP_PRIVATE 0x02
#define MAP_FAILED ((void *)-1)

#define MREMAP_MAYMOVE 1

#endif
