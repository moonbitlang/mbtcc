# About This Project

本项目是mbtcc，是一个使用MoonBit编写的C编译器。

项目结构：

- lexer: 词法分析器
- preprocess: 预处理器
- parser: 语法分析器
- codegen: llvm代码生成
- main: 命令行工具等

使用方法：

以demo.c为例

- `moon run mina -- demo.c --print-tokens`，打印词法分析后的结果

- `moon run main -- demo.c -E` 进行预处理，打印预处理后的代码

- `moon run main -- demo.c --print-ast` 进行语法分析，打印语法分析出来的语法树。

- `moon run main -- demo.c` 期望是输出llvm IR。

注意，项目下有一些以old开头的目录，这是因为mbtcc有过一版重构。不用去管以old为开头的这些目录。

另外，README.md里面的描述并不适用于新的编译器实现，请忽略里面的内容。


# Project Agents.md Guide

This is a [MoonBit](https://docs.moonbitlang.com) project.

## Project Structure

- MoonBit packages are organized per directory, for each directory, there is a
  `package.json` file listing its dependencies. Each package has its files and
  blackbox test files (common, ending in `_test.mbt`) and whitebox test files
  (ending in `_wbtest.mbt`).

- In the toplevel directory, this is a `moon.mod.json` file listing about the
  module and some meta information.

## Coding convention

- MoonBit code is organized in block style, each block is separated by `///|`,
  the order of each block is irrelevant. In some refactorings, you can process
  block by block independently.

- Try to keep deprecated blocks in file called `deprecated.mbt` in each
  directory.

## Tooling

- `moon fmt` is used to format your code properly.

- `moon info` is used to update the generated interface of the package, each
  package has a generated interface file `.mbti`, it is a brief formal
  description of the package. If nothing in `.mbti` changes, this means your
  change does not bring the visible changes to the external package users, it is
  typically a safe refactoring.

- In the last step, run `moon info && moon fmt` to update the interface and
  format the code. Check the diffs of `.mbti` file to see if the changes are
  expected.

- Run `moon test` to check the test is passed. MoonBit supports snapshot
  testing, so when your changes indeed change the behavior of the code, you
  should run `moon test --update` to update the snapshot.

- You can run `moon check` to check the code is linted correctly.

- When writing tests, you are encouraged to use `inspect` and run
  `moon test --update` to update the snapshots, only use assertions like
  `assert_eq` when you are in some loops where each snapshot may vary. You can
  use `moon coverage analyze > uncovered.log` to see which parts of your code
  are not covered by tests.

- agent-todo.md has some small tasks that are easy for AI to pick up, agent is
  welcome to finish the tasks and check the box when you are done
