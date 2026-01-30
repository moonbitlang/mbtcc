#ifndef _MBTCC_ASSERT_H
#define _MBTCC_ASSERT_H

#include <stdlib.h>

#define assert(x) do { if (!(x)) abort(); } while (0)

#endif
