#ifndef _MBTCC_ASSERT_H
#define _MBTCC_ASSERT_H

#include <stdlib.h>

#define assert(x) ((void)((x) ? 0 : (abort(), 0)))

#endif
