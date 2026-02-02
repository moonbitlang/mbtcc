#ifndef MBTCC_STDBOOL_H
#define MBTCC_STDBOOL_H

#ifndef __bool_true_false_are_defined
typedef _Bool bool;
#define true 1
#define false 0
#define __bool_true_false_are_defined 1
#endif

#endif
