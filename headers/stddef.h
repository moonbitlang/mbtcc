#ifndef _MBTCC_STDDEF_H
#define _MBTCC_STDDEF_H

typedef unsigned long size_t;
typedef long ptrdiff_t;

#ifndef MBTCC_WCHAR_T_DEFINED
typedef int wchar_t;
#define MBTCC_WCHAR_T_DEFINED
#endif

#ifndef NULL
#define NULL ((void*)0)
#endif

#ifndef offsetof
#define offsetof(type, member) ((size_t)&(((type *)0)->member))
#endif

#endif
