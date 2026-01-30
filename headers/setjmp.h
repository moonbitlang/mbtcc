#ifndef _MBTCC_SETJMP_H
#define _MBTCC_SETJMP_H

typedef long jmp_buf[24];

int setjmp(long *env);
void longjmp(long *env, int val);

#endif
