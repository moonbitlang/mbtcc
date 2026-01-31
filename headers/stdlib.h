#ifndef _MBTCC_STDLIB_H
#define _MBTCC_STDLIB_H

#include <stddef.h>

void *malloc(size_t size);
void *calloc(size_t nmemb, size_t size);
void *realloc(void *ptr, size_t size);
void free(void *ptr);

int atoi(const char *s);
long atol(const char *s);
double atof(const char *s);

void exit(int status);
int atexit(void (*func)(void));
void abort(void);

#endif
