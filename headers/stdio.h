#ifndef _MBTCC_STDIO_H
#define _MBTCC_STDIO_H

#include <stddef.h>
#include <stdarg.h>

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
int scanf(const char *fmt, ...);
int fprintf(FILE *fp, const char *fmt, ...);
int sprintf(char *buf, const char *fmt, ...);
int fscanf(FILE *fp, const char *fmt, ...);
int sscanf(const char *buf, const char *fmt, ...);
int snprintf(char *buf, size_t n, const char *fmt, ...);
int putchar(int c);
int putc(int c, FILE *fp);
int puts(const char *s);
int getchar(void);
int fgetc(FILE *fp);
int getc(FILE *fp);
char *fgets(char *s, int n, FILE *fp);
int fputc(int c, FILE *fp);
int fputs(const char *s, FILE *fp);
int vprintf(const char *fmt, va_list ap);
int vfprintf(FILE *fp, const char *fmt, va_list ap);
int vsnprintf(char *buf, size_t n, const char *fmt, va_list ap);
int fflush(FILE *fp);
int fseek(FILE *fp, long offset, int whence);
long ftell(FILE *fp);
void rewind(FILE *fp);
int feof(FILE *fp);
int ferror(FILE *fp);
void clearerr(FILE *fp);
int fileno(FILE *fp);

#define EOF (-1)
#define SEEK_SET 0
#define SEEK_CUR 1
#define SEEK_END 2

#define FILENAME_MAX 1024

FILE *fopen(const char *path, const char *mode);
int fclose(FILE *fp);
size_t fread(void *ptr, size_t size, size_t nmemb, FILE *fp);
size_t fwrite(const void *ptr, size_t size, size_t nmemb, FILE *fp);
int rename(const char *oldpath, const char *newpath);
int remove(const char *path);

#endif
