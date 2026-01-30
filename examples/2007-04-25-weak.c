
#if !defined(__linux__) && !defined(__FreeBSD__) && !defined(__NetBSD__) && !defined(__OpenBSD__)
extern int test_weak () __attribute__ ((weak_import));
#else
extern int test_weak () __attribute__ ((weak));
#endif

#if defined(__APPLE__)
__attribute__((weak)) int test_weak(void) { return 0; }
#endif

int main(){
  int (*t)() = test_weak;
  if (t) {
    t();
  }
  return 0;
}
