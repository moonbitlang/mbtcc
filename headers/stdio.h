#ifndef _MBTCC_STDIO_H
#define _MBTCC_STDIO_H

#include <stddef.h>

typedef struct _FILE FILE;
struct _FILE;

#if defined(__APPLE__)
extern FILE *__stdinp;
extern FILE *__stdoutp;
extern FILE *__stderrp;
#define stdin __stdinp
#define stdout __stdoutp
#define stderr __stderrp
#else
extern FILE *stdin;
extern FILE *stdout;
extern FILE *stderr;
#endif

int printf(const char *fmt, ...);
int fprintf(FILE *fp, const char *fmt, ...);
int sprintf(char *buf, const char *fmt, ...);
int snprintf(char *buf, size_t n, const char *fmt, ...);
int putchar(int c);
int puts(const char *s);
int getchar(void);
int fgetc(FILE *fp);
int getc(FILE *fp);
char *fgets(char *s, int n, FILE *fp);

#define EOF (-1)

FILE *fopen(const char *path, const char *mode);
int fclose(FILE *fp);
size_t fread(void *ptr, size_t size, size_t nmemb, FILE *fp);
size_t fwrite(const void *ptr, size_t size, size_t nmemb, FILE *fp);

#endif
