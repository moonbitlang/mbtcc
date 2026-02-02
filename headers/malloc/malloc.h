#ifndef MBTCC_MALLOC_MALLOC_H
#define MBTCC_MALLOC_MALLOC_H

#include <stddef.h>

typedef struct malloc_zone_t malloc_zone_t;
struct malloc_zone_t {
  void *reserved1;
  void *reserved2;
  size_t (*size)(struct malloc_zone_t *zone, const void *ptr);
};

malloc_zone_t *malloc_default_zone(void);
malloc_zone_t *malloc_create_zone(size_t start_size, unsigned flags);
void malloc_destroy_zone(malloc_zone_t *zone);
void malloc_set_zone_name(malloc_zone_t *zone, const char *name);
void *malloc_zone_malloc(malloc_zone_t *zone, size_t size);
void *malloc_zone_realloc(malloc_zone_t *zone, void *ptr, size_t size);
void malloc_zone_free(malloc_zone_t *zone, void *ptr);
size_t malloc_size(const void *ptr);

#endif
