

# 与标准C不一致的行为记录

```c
#define A 5

#if A > ~1UL
  int foo();
#endif
```

上述的宏中，gcc -E后不出现内部的`int foo()`，而mbtcc会出现内部的`int foo()`

问题原因：const_eval的行为与标准C不符。

复现措施：将前面的代码保存到一个文件内，命名为demo.c。分别用`gcc -E demo.c`和`moon run main -- demo.c -E`可以看到。
