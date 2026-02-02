#ifndef MBTCC_DLFCN_H
#define MBTCC_DLFCN_H

void *dlopen(const char *path, int mode);
void *dlsym(void *handle, const char *symbol);
int dlclose(void *handle);
char *dlerror(void);

#define RTLD_LAZY 1
#define RTLD_NOW 2
#define RTLD_GLOBAL 0x100
#define RTLD_LOCAL 0

#endif
