#ifndef MBTCC_PTHREAD_H
#define MBTCC_PTHREAD_H

#include <sys/types.h>

typedef unsigned long pthread_t;

typedef struct {
  long __sig;
  char __opaque[56];
} pthread_mutex_t;

typedef struct {
  int __sig;
  char __opaque[12];
} pthread_mutexattr_t;

typedef struct {
  char __opaque[64];
} pthread_attr_t;

int pthread_mutex_init(pthread_mutex_t *mutex, const pthread_mutexattr_t *attr);
int pthread_mutex_destroy(pthread_mutex_t *mutex);
int pthread_mutex_lock(pthread_mutex_t *mutex);
int pthread_mutex_trylock(pthread_mutex_t *mutex);
int pthread_mutex_unlock(pthread_mutex_t *mutex);

int pthread_mutexattr_init(pthread_mutexattr_t *attr);
int pthread_mutexattr_destroy(pthread_mutexattr_t *attr);
int pthread_mutexattr_settype(pthread_mutexattr_t *attr, int type);

int pthread_equal(pthread_t t1, pthread_t t2);
pthread_t pthread_self(void);

int pthread_create(pthread_t *thread, const pthread_attr_t *attr, void *(*start_routine)(void*), void *arg);
int pthread_join(pthread_t thread, void **retval);

#define PTHREAD_MUTEX_INITIALIZER {0, {0}}
#define PTHREAD_MUTEX_RECURSIVE 2

#endif
