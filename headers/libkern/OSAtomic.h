#ifndef MBTCC_LIBKERN_OSATOMIC_H
#define MBTCC_LIBKERN_OSATOMIC_H

typedef int Boolean;

Boolean OSAtomicCompareAndSwapPtrBarrier(void *oldValue, void *newValue, void *volatile *theValue);

#endif
