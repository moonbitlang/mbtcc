#!/usr/bin/env python3
"""
mbtcc examples 回归测试脚本（对比 clang 直编 vs mbtcc 生成 LLVM IR 后再 clang）

流程（对每个 examples 下的 .c 文件）：
1) clang examples/{file}.c -> {file}.std.out，运行并捕获输出（作为参考输出）
2) moon run main -- examples/{file}.c -o {file}.ll
3) clang {file}.ll -> {file}.mbt.out，运行并捕获输出
4) 对比两次运行输出，一致则通过

说明：
- 默认比较采用 strip()（忽略首尾空白差异），与仓库里的 demo_test.py 一致。
- 构建产物默认写入 tmp/mbtcc_test/，避免污染仓库根目录。
"""

from __future__ import annotations

import argparse
import difflib
import glob
import os
import shutil
import subprocess
import sys
import time
from dataclasses import dataclass
from typing import Optional, Tuple, List


class Colors:
    GREEN = "\033[92m"
    RED = "\033[91m"
    YELLOW = "\033[93m"
    BLUE = "\033[94m"
    END = "\033[0m"
    BOLD = "\033[1m"


class FailureReason:
    CLANG_COMPILE_ERROR = "clang 编译失败"
    MOON_COMPILE_ERROR = "moon 生成 LLVM IR 失败"
    LL_CLANG_ERROR = "clang 编译 LLVM IR 失败"
    RUN_ERROR = "运行失败"
    OUTPUT_MISMATCH = "输出不匹配"
    MISSING_TOOL = "缺少依赖工具"


@dataclass
class CmdResult:
    returncode: int
    stdout: str
    stderr: str


def run_command(cmd: str, timeout: int = 30, cwd: Optional[str] = None) -> CmdResult:
    try:
        t0 = time.perf_counter()
        r = subprocess.run(
            cmd,
            shell=True,
            cwd=cwd,
            capture_output=True,
            text=True,
            timeout=timeout,
        )
        _ = time.perf_counter() - t0
        return CmdResult(r.returncode, r.stdout, r.stderr)
    except subprocess.TimeoutExpired:
        return CmdResult(-1, "", "Timeout")
    except Exception as e:
        return CmdResult(-1, "", str(e))


def check_tool_or_exit(name: str) -> None:
    if shutil.which(name) is None:
        print(f"{Colors.RED}{Colors.BOLD}错误:{Colors.END} 未找到 `{name}`，无法运行测试。")
        sys.exit(1)


def discover_c_files(examples_dir: str, recursive: bool) -> List[str]:
    if recursive:
        # glob 递归要用 ** 并设置 recursive=True
        pattern = os.path.join(examples_dir, "**", "*.c")
        files = glob.glob(pattern, recursive=True)
    else:
        pattern = os.path.join(examples_dir, "*.c")
        files = glob.glob(pattern)
    files = [f for f in files if os.path.isfile(f)]
    files.sort()
    return files


def safe_id_from_relpath(relpath: str) -> str:
    # examples/foo/bar.c -> foo__bar
    relpath = relpath.replace("\\", "/")
    if relpath.endswith(".c"):
        relpath = relpath[:-2]
    return relpath.replace("/", "__")


def normalize_output(s: str, strict: bool) -> str:
    # 统一换行符，避免 CRLF 造成误判
    s = s.replace("\r\n", "\n")
    return s if strict else s.strip()


def _vprint(verbose: bool, msg: str) -> None:
    if verbose:
        print(msg)


def _run_step(cmd: str, timeout: int, verbose: bool) -> CmdResult:
    if verbose:
        print(f"{Colors.BLUE}$ {cmd}{Colors.END}")
    t0 = time.perf_counter()
    r = run_command(cmd, timeout=timeout)
    dt = time.perf_counter() - t0
    if verbose:
        print(f"  -> exit={r.returncode}, time={dt:.3f}s")
    return r


def compile_and_run_clang_c(
    c_file: str, std_exe: str, timeout: int, verbose: bool
) -> Tuple[bool, str, str, str]:
    # 返回 (success, out, err, reason)
    cmd = f'clang "{c_file}" -o "{std_exe}" -lm'
    r = _run_step(cmd, timeout=timeout, verbose=verbose)
    if r.returncode != 0:
        return False, "", r.stderr, FailureReason.CLANG_COMPILE_ERROR
    rr = _run_step(f'"{std_exe}"', timeout=timeout, verbose=verbose)
    if rr.returncode != 0:
        return False, rr.stdout, rr.stderr, FailureReason.RUN_ERROR
    return True, rr.stdout, rr.stderr, ""


def compile_and_run_mbtcc_ll(
    c_file: str, ll_file: str, mbt_exe: str, timeout: int, verbose: bool
) -> Tuple[bool, str, str, str]:
    # 1) moon -> .ll
    r = _run_step(f'moon run main -- "{c_file}" -o "{ll_file}"', timeout=timeout, verbose=verbose)
    if r.returncode != 0:
        return False, r.stdout, r.stderr, FailureReason.MOON_COMPILE_ERROR
    if (not os.path.exists(ll_file)) or os.path.getsize(ll_file) == 0:
        return False, r.stdout, r.stderr, FailureReason.MOON_COMPILE_ERROR

    # 2) clang .ll -> exe
    rr = _run_step(f'clang "{ll_file}" -o "{mbt_exe}" -lm', timeout=timeout, verbose=verbose)
    if rr.returncode != 0:
        return False, rr.stdout, rr.stderr, FailureReason.LL_CLANG_ERROR

    # 3) run exe
    rrr = _run_step(f'"{mbt_exe}"', timeout=timeout, verbose=verbose)
    if rrr.returncode != 0:
        return False, rrr.stdout, rrr.stderr, FailureReason.RUN_ERROR
    return True, rrr.stdout, rrr.stderr, ""


def unified_diff(a: str, b: str, fromfile: str, tofile: str, max_lines: int = 200) -> str:
    diff = list(
        difflib.unified_diff(
            a.splitlines(keepends=True),
            b.splitlines(keepends=True),
            fromfile=fromfile,
            tofile=tofile,
        )
    )
    if len(diff) > max_lines:
        diff = diff[:max_lines] + ["\n... diff 截断 ...\n"]
    return "".join(diff)


def main() -> int:
    ap = argparse.ArgumentParser(description="对比 examples 下每个 C 文件在 clang 与 mbtcc(llvm) 下的输出一致性")
    ap.add_argument("--examples-dir", default="examples", help="examples 目录（默认: examples）")
    ap.add_argument("--build-dir", default=os.path.join("tmp", "mbtcc_test"), help="构建产物输出目录")
    ap.add_argument("--file", "-f", default=None, help="仅测试单个 C 文件（路径）")
    ap.add_argument("--recursive", action="store_true", help="递归扫描 examples 子目录")
    ap.add_argument("--timeout", type=int, default=10, help="每条命令的超时秒数（默认 10）")
    ap.add_argument("--keep", action="store_true", help="保留构建产物（默认会保留在 build-dir 中，不做清理）")
    ap.add_argument("--strict", action="store_true", help="严格比较输出（不做 strip，只统一换行符）")
    ap.add_argument("--verbose", action="store_true", help="输出每一步执行的命令与耗时")
    args = ap.parse_args()

    check_tool_or_exit("clang")
    check_tool_or_exit("moon")

    examples_dir = args.examples_dir
    if not os.path.isdir(examples_dir):
        print(f"{Colors.RED}{Colors.BOLD}错误:{Colors.END} 找不到目录 `{examples_dir}`")
        return 1

    os.makedirs(args.build_dir, exist_ok=True)

    if args.file:
        c_files = [args.file]
    else:
        c_files = discover_c_files(examples_dir, recursive=args.recursive)

    if not c_files:
        print(f"{Colors.YELLOW}未找到任何 .c 文件（目录: {examples_dir}）{Colors.END}")
        return 0

    print(f"{Colors.BOLD}开始测试{Colors.END}: 共 {len(c_files)} 个文件")
    print(f"- examples: {examples_dir}")
    print(f"- build: {args.build_dir}")
    print(f"- compare: {'strict' if args.strict else 'strip'}\n")

    passed = 0
    failures = []

    for c_file in c_files:
        if not os.path.exists(c_file):
            failures.append((c_file, "文件不存在", "", ""))
            print(f"{Colors.RED}✗{Colors.END} {c_file} (文件不存在)")
            continue
        if not c_file.endswith(".c"):
            # 跳过非 .c
            continue

        rel = os.path.relpath(c_file, examples_dir) if os.path.commonpath([os.path.abspath(c_file), os.path.abspath(examples_dir)]) == os.path.abspath(examples_dir) else os.path.basename(c_file)
        file_id = safe_id_from_relpath(rel)

        std_exe = os.path.join(args.build_dir, f"{file_id}.std.out")
        ll_file = os.path.join(args.build_dir, f"{file_id}.ll")
        mbt_exe = os.path.join(args.build_dir, f"{file_id}.mbt.out")

        if args.verbose:
            print(f"\n{Colors.BOLD}==> {c_file}{Colors.END}")
            print(f"  std_exe: {std_exe}")
            print(f"  ll_file: {ll_file}")
            print(f"  mbt_exe: {mbt_exe}")

        ok1, out1, err1, reason1 = compile_and_run_clang_c(
            c_file, std_exe, timeout=args.timeout, verbose=args.verbose
        )
        if not ok1:
            failures.append((c_file, reason1, err1, ""))
            print(f"{Colors.RED}✗{Colors.END} {c_file} ({reason1})")
            continue

        ok2, out2, err2, reason2 = compile_and_run_mbtcc_ll(
            c_file, ll_file, mbt_exe, timeout=args.timeout, verbose=args.verbose
        )
        if not ok2:
            failures.append((c_file, reason2, err2, ""))
            print(f"{Colors.RED}✗{Colors.END} {c_file} ({reason2})")
            continue

        n1 = normalize_output(out1, strict=args.strict)
        n2 = normalize_output(out2, strict=args.strict)
        if n1 == n2:
            passed += 1
            print(f"{Colors.GREEN}✓{Colors.END} {c_file}")
        else:
            diff = unified_diff(
                n1 + ("\n" if not n1.endswith("\n") else ""),
                n2 + ("\n" if not n2.endswith("\n") else ""),
                fromfile="clang(c).stdout",
                tofile="mbtcc(ll).stdout",
            )
            failures.append((c_file, FailureReason.OUTPUT_MISMATCH, diff, f"clang stderr:\n{err1}\n\nmbtcc stderr:\n{err2}"))
            print(f"{Colors.RED}✗{Colors.END} {c_file} ({FailureReason.OUTPUT_MISMATCH})")

    total = passed + len(failures)
    print(f"\n{Colors.BOLD}{'='*60}{Colors.END}")
    print(f"{Colors.BOLD}结果:{Colors.END} {passed}/{total} 通过")

    if failures:
        print(f"\n{Colors.RED}{Colors.BOLD}失败详情:{Colors.END}")
        for (c_file, reason, detail, extra) in failures:
            print(f"\n- {Colors.BOLD}{c_file}{Colors.END}: {reason}")
            if detail:
                print(detail)
            if extra:
                # 避免输出太长：仅在非 diff 场景下输出 stderr
                if reason != FailureReason.OUTPUT_MISMATCH:
                    print(extra)
        return 1

    return 0


if __name__ == "__main__":
    raise SystemExit(main())

