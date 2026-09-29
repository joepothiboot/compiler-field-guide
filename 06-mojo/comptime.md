# comptime ⏱️

> **One line:** `comptime` asks the compiler to evaluate something while
> compiling: a constant (`comptime X = ...`), a branch (`comptime if`) or an
> unrolled loop (`comptime for`). Ordinary Mojo functions can run at compile
> time, so there is no separate macro language.

## 🌉 From frontend

Like a bundler's `define` plugin plus dead-code elimination:
`if (process.env.NODE_ENV === "production")` is decided at build time, and
the other branch disappears from the bundle. `comptime` makes this a
language feature, and it can run real functions (below: Fibonacci) during
the build.

## 🖼️ Picture

```
 source                                   what gets compiled
 ──────                                   ──────────────────
 comptime FIB_20 = fib(20)          ──►   FIB_20 = 6765  (a constant; fib never runs at runtime)

 comptime if CompilationTarget          ──►   only the Apple Silicon branch
     .is_apple_silicon(): ...                  (the other branch is not compiled at all)
 else: ...

 comptime for i in range(3):        ──►   copy 0: square = 0
     comptime square = i * i               copy 1: square = 1
     print(i, square)                      copy 2: square = 4
                                           (three straight-line copies, no loop)
```

## 🔧 In each tool

Real run of [samples/mojo_comptime.mojo](../samples/mojo_comptime.mojo) on
this M2:

```mojo
comptime TILE = 4 * 16

def fib(n: Int) -> Int:
    return n if n < 2 else fib(n - 1) + fib(n - 2)

comptime FIB_20 = fib(20)               # evaluated by the compiler

def kernel_for_this_cpu():
    comptime if CompilationTarget.is_apple_silicon():
        print("  compiled the Apple Silicon path, width", simd_width_of[DType.float32]())
    else:
        print("  compiled the generic path")

def main():
    print("  TILE =", TILE, " FIB_20 =", FIB_20)
    kernel_for_this_cpu()
    comptime for i in range(3):
        comptime square = i * i
        print("  unrolled copy", i, "square", square)
```

```
  TILE = 64  FIB_20 = 6765
  compiled the Apple Silicon path, width 4
  unrolled copy 0 square 0
  unrolled copy 1 square 1
  unrolled copy 2 square 4
```

| Language / tool | Compile-time evaluation                                                |
| --------------- | ---------------------------------------------------------------------- |
| Mojo            | `comptime` values, `comptime if`, `comptime for`, parameters           |
| C++             | `constexpr` / `consteval` functions, `if constexpr`, templates         |
| Zig             | `comptime` (the same idea and name)                                    |
| Triton          | `tl.constexpr` values; `tl.static_range` for unrolled loops            |
| MLIR / LLVM     | Constant folding and loop unrolling passes (automatic, not guaranteed) |

## ⚠️ Common confusion

- **Older syntax is now an error.** Pre-1.0 Mojo used `alias X = ...`,
  `@parameter if` and `@parameter for`, and older posts still show them.
  Mojo 1.1 rejects them. Real errors: `'for' statement does not support
decorators; remove the decorator` for `@parameter for`, and a parse error
  for `alias`. Use `comptime` for all three.
- **Guaranteed vs hoped-for.** An optimizer _may_ unroll a loop or fold a
  constant. `comptime` _guarantees_ it, or fails to compile. For kernels,
  this predictability is the point.
- **Not every value can cross to runtime.** A compile-time value of a
  complex type may need `materialize[...]()` to be used at runtime. Real
  error from printing a `Layout` directly: `cannot materialize comptime value
of type 'Layout' to runtime because it is not 'ImplicitlyCopyable'`.

## 🔗 Related

- [Parameters vs arguments](parameters-vs-arguments.md)
- [Canonicalization and folding](../03-transformations/canonicalization-and-folding.md)
- [Autotuning](../05-ml-compilers/autotuning.md): `comptime for` as a sweep

---

✅ Verified against: Mojo 1.1.0 (run locally)
