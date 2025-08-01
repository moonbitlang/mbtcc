# Kaida-Amethyst/mbtcc

mbtcc是一个使用moonbit编写的c编译器，支持c11标准。目的是为了验证llvm.mbt的功能，以及为MoonLLVM项目提供前端实现。

## RoadMap

[x] 词法分析
[ ] 语法分析
[ ] 语义检查
[ ] 提供友好的错误提示
[ ] 预处理器实现
[ ] llvm代码生成 (llvm.mbt)
[ ] llvm代码生成 (MoonLLVM)
[ ] 调试器
[ ] 自举编译Moonbit生成的C后端
[ ] 编译复杂大型项目，lua，sqlite等。
[ ] 尝试将mbtcc替代掉moonbit的tcc编译器

