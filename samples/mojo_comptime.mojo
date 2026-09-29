# comptime: values, branches and loops evaluated while compiling.
from std.sys import CompilationTarget, simd_width_of

comptime TILE = 4 * 16  # a compile-time constant


def fib(n: Int) -> Int:  # an ordinary function...
    return n if n < 2 else fib(n - 1) + fib(n - 2)


comptime FIB_20 = fib(20)  # ...evaluated by the compiler


def kernel_for_this_cpu():
    comptime if CompilationTarget.is_apple_silicon():  # only one branch is compiled
        print("  compiled the Apple Silicon path, width", simd_width_of[DType.float32]())
    else:
        print("  compiled the generic path")


def main():
    print("  TILE =", TILE, " FIB_20 =", FIB_20)
    kernel_for_this_cpu()
    comptime for i in range(3):
        comptime square = i * i  # a new compile-time value per unrolled copy
        print("  unrolled copy", i, "square", square)
