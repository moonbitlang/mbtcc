# chibicc 测试用例 port 到 `examples/` 的推荐顺序（从易到难）

目标：把 `chibicc/test/*.c` 的覆盖面逐步迁移到本仓库的 `examples/`，并用 `test.py` 做回归（clang 直编输出 vs mbtcc 生成 LLVM 再运行输出）。

核心原则：**小步快跑**、每次只引入少量新特性、遇到 GNU 扩展时优先**改写成标准 C**再引入。

---

### 0. 前置：决定顺序的“门槛能力”

#### 0.1 预处理器现状（`preprocess/`）
- **已支持**：`#include "..."`、`#pragma once`、对象宏/函数宏、`__VA_ARGS__`、条件编译、`defined`、`#param`（stringizing）
- **暂不建议立刻依赖**：`#include <...>`、`#include` 行内宏展开、`##`、`__VA_OPT__`、`#include_next`、部分内建宏一致性（如 `__COUNTER__`）

#### 0.2 语法层面的“常见改写点”
chibicc 的 `test/*.c` 大量使用 GNU 扩展：
- **statement expression**：`({ ...; expr; })`
- **labels as values / computed goto**：`&&label`、`goto *p`
- **case range**：`case 0 ... 5:`

早期 port 建议跳过这些，或改写成标准 C（拆成多条语句 + 局部变量 + `ASSERT`）。

---

### 1. 分阶段推荐顺序（从易到难）

#### 第 1 阶段：基础表达式 + 基础语句（最容易）
- **目标**：快速验证 lexer/parser/codegen 的骨架正确，跑通 port 流程与测试方式。
- **优先来源**：`arith.c`（纯表达式子集）、`control.c`（标准 if/for/while/switch 子集）、`variable.c`（标准作用域子集）
- **建议产出文件**：
  - `examples/chibicc_arith_basic.c`
  - `examples/chibicc_control_basic.c`

#### 第 2 阶段：函数调用 + 指针/数组（容易）
- **目标**：覆盖调用、递归、数组退化、指针算术与下标。
- **优先来源**：`function.c`（非 varargs/非 builtin 子集）、`pointer.c`
- **建议产出文件**：
  - `examples/chibicc_function_basic.c`
  - `examples/chibicc_pointer_array.c`

#### 第 3 阶段：struct/union/typedef/enum + initializer（中等）
- **目标**：类型系统与内存布局开始复杂，容易暴露 layout/codegen bug。
- **优先来源**：`struct.c`、`union.c`、`typedef.c`、`enum.c`、`initializer.c`（先挑简单部分）
- **建议产出文件**：
  - `examples/chibicc_struct_union.c`
  - `examples/chibicc_initializer_basic.c`

#### 第 4 阶段：cast/sizeof/alignof/offsetof/const/constexpr（中等偏难）
- **目标**：补齐类型转换、常量表达式与布局相关内建。
- **优先来源**：`cast.c`、`sizeof.c`、`alignof.c`、`offsetof.c`、`const.c`、`constexpr.c`

#### 第 5 阶段：预处理器专项（建议拆小做，难度波动很大）
- **目标**：逐步吃掉 `macro.c`/`pragma-once.c`/`line.c`/include 相关用例。
- **推荐顺序（子集）**：
  - **5.1（容易）**：`#if/#ifdef/#ifndef/#elif/#else/#endif`、`defined`、对象宏/函数宏、`__VA_ARGS__`、`#param`
  - **5.2（中等）**：`#pragma once`、`#include "..."` 递归与重复 include
  - **5.3（更难，先补功能再做）**：`#include` 行内宏展开、`##`、`__VA_OPT__`、`#include_next`、`__COUNTER__` 等

#### 第 6 阶段：高级/平台相关/扩展特性（最难，最后做）
- **候选**：`varargs.c`、`vla.c`、`alloca.c`、`float.c`、`usualconv.c`、`typeof.c`、`generic.c`、`atomic.c`、`tls.c`、`asm.c`、`attribute.c`、`unicode.c`、`stdhdr.c`、`compat.c`
- **建议**：每次只挑 1 个主题做“最小子集”，并在文档里记录“实现前置条件”。

---

### 2. 具体建议：每阶段挑选策略（避免一次性搬整文件）

#### 2.1 每次 port 的粒度
- **建议**：每次从一个 `chibicc/test/*.c` 里挑 10~30 个 `ASSERT` 迁移，落到一个新的 `examples/chibicc_*.c`。
- **好处**：定位回归更快，避免一次引入多个新特性导致排查困难。

#### 2.2 遇到 GNU 扩展时的处理原则
- **statement expression**：改写为 `{ ...; tmp = ...; } ASSERT(expected, tmp);`
- **computed goto / case range**：早期直接跳过，后期若要支持，再单开 `examples/chibicc_gnu_ext_*.c` 专项。

#### 2.3 预处理器相关用例的分拆建议
`macro.c` 覆盖面太广，建议按能力拆成多个 `examples/chibicc_macro_*.c`：
- `chibicc_macro_cond.c`：条件编译 + defined
- `chibicc_macro_define.c`：对象宏/函数宏/`__VA_ARGS__`
- `chibicc_macro_stringize.c`：`#param`（已支持）
- `chibicc_macro_include.c`：include/pragma once（先只做 `"..."`）
- `chibicc_macro_paste.c`：`##`（后置）
- `chibicc_macro_va_opt.c`：`__VA_OPT__`（后置）

