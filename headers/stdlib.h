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
long strtol(const char *s, char **endptr, int base);
unsigned long strtoul(const char *s, char **endptr, int base);
double strtod(const char *s, char **endptr);

char *getenv(const char *name);
int system(const char *command);

void exit(int status);
int atexit(void (*func)(void));
void abort(void);
long random(void);
void srandom(unsigned int seed);
void srandomdev(void);
int rand(void);
void srand(unsigned int seed);

#endif
